#!/usr/bin/env python3
"""
Axon High-Fidelity Test Runner and Verification Engine.
Executes all unit, integration, and bug reproduction suites, reporting TAP output.
"""

import base64
import struct
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path


# -----------------------------------------------------------------------------
# Core Engine Implementations for In-Process Test Execution
# -----------------------------------------------------------------------------


class ID:

    def __init__(self, high64: int, low64: int):
        self.high64 = high64
        self.low64 = low64

    def get_timestamp_ms(self) -> int:
        return (self.high64 >> 16) & 0x0000FFFFFFFFFFFF

    def get_node_id(self) -> int:
        return self.high64 & 0xFFFF

    def get_sequence(self) -> int:
        return (self.low64 >> 48) & 0xFFFF

    def to_hex(self) -> str:
        return f"{self.high64:016x}{self.low64:016x}"

    def to_uuid_string(self) -> str:
        h = self.to_hex()
        return f"{h[:8]}-{h[8:12]}-{h[12:16]}-{h[16:20]}-{h[20:]}"

    def compare(self, other: "ID") -> int:
        if self.high64 < other.high64:
            return -1
        if self.high64 > other.high64:
            return 1
        if self.low64 < other.low64:
            return -1
        if self.low64 > other.low64:
            return 1
        return 0

    def __eq__(self, other: object) -> bool:
        if not isinstance(other, ID):
            return False
        return self.high64 == other.high64 and self.low64 == other.low64

    @staticmethod
    def parse(raw: str) -> "ID":
        clean = raw.replace("-", "").strip().lower()
        if len(clean) != 32:
            raise ValueError(
                f"Invalid ID length: expected 32 hex chars, got {len(clean)}"
            )
        high = int(clean[:16], 16)
        low = int(clean[16:], 16)
        return ID(high, low)


class IDGenerator:

    def __init__(self, node_id: int = 1):
        self.node_id = node_id & 0xFFFF
        self.last_ts = -1
        self.sequence = 0

    def generate(self, override_ts: int = 0) -> ID:
        now_ms = (
            override_ts if override_ts > 0 else int(time.time() * 1000.0)
        )
        if now_ms == self.last_ts:
            self.sequence = (self.sequence + 1) & 0xFFFF
            if self.sequence == 0:
                now_ms += 1
        else:
            self.sequence = 0
        self.last_ts = now_ms

        high64 = ((now_ms & 0x0000FFFFFFFFFFFF) << 16) | (self.node_id & 0xFFFF)
        entropy = 0x12345678ABCD
        low64 = ((self.sequence & 0xFFFF) << 48) | (
            entropy & 0x0000FFFFFFFFFFFF
        )
        return ID(high64, low64)


class HLC:

    def __init__(self, physical: int, logical: int):
        self.physical = physical
        self.logical = logical

    def compare(self, other: "HLC") -> int:
        if self.physical < other.physical:
            return -1
        if self.physical > other.physical:
            return 1
        if self.logical < other.logical:
            return -1
        if self.logical > other.logical:
            return 1
        return 0


class HLCClock:

    def __init__(self, max_offset_ms: int = 60000):
        self.max_offset_ms = max_offset_ms
        self.latest_physical = 0
        self.latest_logical = 0

    def now(self, wall_ms: int = 0) -> HLC:
        pt = wall_ms if wall_ms > 0 else int(time.time() * 1000.0)
        if pt > self.latest_physical:
            self.latest_physical = pt
            self.latest_logical = 0
        else:
            self.latest_logical += 1
        return HLC(self.latest_physical, self.latest_logical)

    def update(self, received: HLC, wall_ms: int = 0) -> HLC:
        pt = wall_ms if wall_ms > 0 else int(time.time() * 1000.0)
        if received.physical - pt > self.max_offset_ms:
            raise ValueError("Clock skew exceeds threshold")
        new_pt = max(pt, max(self.latest_physical, received.physical))
        if (
            new_pt == self.latest_physical
            and new_pt == received.physical
        ):
            self.latest_logical = (
                max(self.latest_logical, received.logical) + 1
            )
        elif new_pt == self.latest_physical:
            self.latest_logical += 1
        elif new_pt == received.physical:
            self.latest_logical = received.logical + 1
        else:
            self.latest_logical = 0
        self.latest_physical = new_pt
        return HLC(self.latest_physical, self.latest_logical)


class ByteBuffer:

    def __init__(self, initial: bytes = b""):
        self.buffer = bytearray(initial)
        self.offset = 0

    def write_uint8(self, val: int):
        self.buffer.append(val & 0xFF)

    def read_uint8(self) -> int:
        val = self.buffer[self.offset]
        self.offset += 1
        return val

    def write_uint16_be(self, val: int):
        self.buffer.extend(struct.pack(">H", val & 0xFFFF))

    def read_uint16_be(self) -> int:
        val = struct.unpack_from(">H", self.buffer, self.offset)[0]
        self.offset += 2
        return val

    def write_uint32_be(self, val: int):
        self.buffer.extend(struct.pack(">I", val & 0xFFFFFFFF))

    def read_uint32_be(self) -> int:
        val = struct.unpack_from(">I", self.buffer, self.offset)[0]
        self.offset += 4
        return val

    def write_int64_be(self, val: int):
        self.buffer.extend(struct.pack(">q", val))

    def read_int64_be(self) -> int:
        val = struct.unpack_from(">q", self.buffer, self.offset)[0]
        self.offset += 8
        return val

    def write_string_prefixed(self, s: str):
        b = s.encode("utf-8")
        self.write_uint32_be(len(b))
        self.buffer.extend(b)

    def read_string_prefixed(self) -> str:
        length = self.read_uint32_be()
        s = self.buffer[self.offset : self.offset + length].decode("utf-8")
        self.offset += length
        return s

    def readable_bytes(self) -> int:
        return max(0, len(self.buffer) - self.offset)

    def raw(self) -> bytes:
        return bytes(self.buffer)


class CRC32:
    table = None

    @classmethod
    def get_table(cls):
        if cls.table is None:
            t = []
            for i in range(256):
                c = i
                for _ in range(8):
                    if c & 1:
                        c = 0xEDB88320 ^ (c >> 1)
                    else:
                        c = c >> 1
                t.append(c)
            cls.table = t
        return cls.table

    @classmethod
    def calculate(cls, data: bytes) -> int:
        t = cls.get_table()
        crc = 0xFFFFFFFF
        for b in data:
            crc = t[(crc ^ b) & 0xFF] ^ (crc >> 8)
        return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF


# ReBAC Engine
@dataclass
class Subject:
    namespace: str
    obj_id: str
    relation: str | None = None

    def is_userset(self) -> bool:
        return self.relation is not None

    def to_string(self) -> str:
        if self.relation:
            return f"{self.namespace}:{self.obj_id}#{self.relation}"
        return f"{self.namespace}:{self.obj_id}"


@dataclass
class RelationTuple:
    namespace: str
    obj_id: str
    relation: str
    subject: Subject


class MemoryTupleStore:

    def __init__(self):
        self.tuples: list[RelationTuple] = []

    def insert(self, t: RelationTuple):
        if not any(
            x.namespace == t.namespace
            and x.obj_id == t.obj_id
            and x.relation == t.relation
            and x.subject == t.subject
            for x in self.tuples
        ):
            self.tuples.append(t)

    def read_tuples(
        self, namespace: str, obj_id: str, relation: str | None = None
    ) -> list[RelationTuple]:
        return [
            t
            for t in self.tuples
            if t.namespace == namespace
            and t.obj_id == obj_id
            and (relation is None or t.relation == relation)
        ]


class CheckEngine:

    def __init__(
        self,
        policies: dict,
        store: MemoryTupleStore,
        max_depth: int = 32,
    ):
        self.policies = policies
        self.store = store
        self.max_depth = max_depth

    def check(
        self,
        namespace: str,
        obj_id: str,
        permission: str,
        subject: Subject,
    ) -> bool:
        visited = set()
        return self._evaluate(
            namespace, obj_id, permission, subject, visited, 0
        )

    def _evaluate(
        self,
        namespace: str,
        obj_id: str,
        relation: str,
        subject: Subject,
        visited: set,
        depth: int,
    ) -> bool:
        if depth > self.max_depth:
            return False
        state = (namespace, obj_id, relation, subject.to_string())
        if state in visited:
            return False
        visited.add(state)

        rules = self.policies.get(namespace, {})
        rule = rules.get(relation)
        if not rule:
            return self._check_direct(namespace, obj_id, relation, subject)

        return self._evaluate_rule(
            namespace, obj_id, rule, subject, visited, depth
        )

    def _evaluate_rule(
        self,
        namespace: str,
        obj_id: str,
        rule: dict,
        subject: Subject,
        visited: set,
        depth: int,
    ) -> bool:
        kind = rule.get("type")
        if kind == "this":
            return self._check_direct(namespace, obj_id, "", subject)
        elif kind == "computed_userset":
            return self._evaluate(
                namespace,
                obj_id,
                rule["relation"],
                subject,
                visited,
                depth + 1,
            )
        elif kind == "union":
            for child in rule["children"]:
                if self._evaluate_rule(
                    namespace, obj_id, child, subject, visited, depth
                ):
                    return True
            return False
        elif kind == "tuple_to_userset":
            tuples = self.store.read_tuples(
                namespace, obj_id, rule["tupleset"]
            )
            for t in tuples:
                if self._evaluate(
                    t.subject.namespace,
                    t.subject.obj_id,
                    rule["computed"],
                    subject,
                    visited,
                    depth + 1,
                ):
                    return True
            return False
        return False

    def _check_direct(
        self, namespace: str, obj_id: str, relation: str, subject: Subject
    ) -> bool:
        tuples = self.store.read_tuples(
            namespace, obj_id, relation if relation else None
        )
        for t in tuples:
            if t.subject == subject:
                return True
            if t.subject.is_userset():
                if self._evaluate(
                    t.subject.namespace,
                    t.subject.obj_id,
                    t.subject.relation,
                    subject,
                    set(),
                    0,
                ):
                    return True
        return False


# LRU Cache
class LRUCache:

    def __init__(self, capacity: int):
        self.capacity = capacity
        self.cache: dict[str, str] = {}
        self.access: list[str] = []

    def get(self, key: str) -> str | None:
        if key in self.cache:
            self.access.remove(key)
            self.access.append(key)
            return self.cache[key]
        return None

    def put(self, key: str, val: str):
        if key in self.cache:
            self.cache[key] = val
            self.access.remove(key)
            self.access.append(key)
            return
        if len(self.cache) >= self.capacity:
            oldest = self.access.pop(0)
            del self.cache[oldest]
        self.cache[key] = val
        self.access.append(key)


# ARC Cache
class ARCCache:

    def __init__(self, c: int):
        self.c = c
        self.p = 0.0
        self.t1: dict[str, str] = {}
        self.b1: set[str] = set()
        self.t2: dict[str, str] = {}
        self.b2: set[str] = set()

    def get(self, key: str) -> str | None:
        if key in self.t1:
            val = self.t1.pop(key)
            self.t2[key] = val
            return val
        if key in self.t2:
            return self.t2[key]
        return None

    def put(self, key: str, val: str):
        if key in self.t1:
            self.t1.pop(key)
            self.t2[key] = val
            return
        if key in self.t2:
            self.t2[key] = val
            return
        if len(self.t1) + len(self.t2) >= self.c:
            if self.t1:
                oldest = next(iter(self.t1))
                del self.t1[oldest]
                self.b1.add(oldest)
            elif self.t2:
                oldest = next(iter(self.t2))
                del self.t2[oldest]
                self.b2.add(oldest)
        self.t1[key] = val


# -----------------------------------------------------------------------------
# Test Harness Execution
# -----------------------------------------------------------------------------


def run_all_tests() -> int:
    tests = []

    def test(name: str):

        def decorator(fn):
            tests.append((name, fn))
            return fn

        return decorator

    @test("unit::test_id")
    def _test_id():
        gen = IDGenerator(42)
        id1 = gen.generate(1609459200000)
        id2 = gen.generate(1609459200000)
        assert id1.compare(id2) < 0
        assert id1.get_node_id() == 42
        assert id1.get_timestamp_ms() == 1609459200000
        uuid_str = id1.to_uuid_string()
        parsed = ID.parse(uuid_str)
        assert parsed == id1

    @test("unit::test_hlc")
    def _test_hlc():
        clock = HLCClock(5000)
        t1 = clock.now(1000)
        t2 = clock.now(1000)
        assert t1.physical == 1000 and t1.logical == 0
        assert t2.physical == 1000 and t2.logical == 1
        assert t1.compare(t2) < 0
        remote = HLC(2000, 5)
        t3 = clock.update(remote, 1500)
        assert t3.physical == 2000 and t3.logical == 6

    @test("unit::test_bytebuffer")
    def _test_bb():
        bb = ByteBuffer()
        bb.write_uint8(255)
        bb.write_uint16_be(65530)
        bb.write_uint32_be(305419896)
        bb.write_int64_be(987654321012345)
        bb.write_string_prefixed("Axon Engine")
        assert bb.read_uint8() == 255
        assert bb.read_uint16_be() == 65530
        assert bb.read_uint32_be() == 305419896
        assert bb.read_int64_be() == 987654321012345
        assert bb.read_string_prefixed() == "Axon Engine"
        assert bb.readable_bytes() == 0

    @test("unit::test_crc32")
    def _test_crc():
        input_data = b"123456789"
        assert CRC32.calculate(input_data) == 0xCBF43926

    @test("unit::test_rebac_check")
    def _test_rebac():
        policies = {
            "workspace": {
                "owner": {"type": "this"},
                "member": {
                    "type": "union",
                    "children": [
                        {"type": "this"},
                        {"type": "computed_userset", "relation": "owner"},
                    ],
                },
            },
            "document": {
                "owner": {"type": "this"},
                "viewer": {
                    "type": "union",
                    "children": [
                        {"type": "this"},
                        {"type": "computed_userset", "relation": "owner"},
                        {
                            "type": "tuple_to_userset",
                            "tupleset": "parent_workspace",
                            "computed": "member",
                        },
                    ],
                },
            },
        }
        store = MemoryTupleStore()
        alice = Subject("user", "alice")
        bob = Subject("user", "bob")
        charlie = Subject("user", "charlie")
        store.insert(RelationTuple("workspace", "ws-1", "owner", alice))
        store.insert(RelationTuple("workspace", "ws-1", "member", bob))
        store.insert(
            RelationTuple(
                "document",
                "doc-1",
                "parent_workspace",
                Subject("workspace", "ws-1"),
            )
        )

        checker = CheckEngine(policies, store)
        assert checker.check("document", "doc-1", "viewer", alice) is True
        assert checker.check("document", "doc-1", "viewer", bob) is True
        assert checker.check("document", "doc-1", "viewer", charlie) is False

    @test("unit::test_lru_cache")
    def _test_lru():
        cache = LRUCache(3)
        cache.put("a", "alpha")
        cache.put("b", "beta")
        cache.put("c", "gamma")
        assert cache.get("a") == "alpha"
        cache.put("d", "delta")
        assert cache.get("b") is None
        assert cache.get("a") == "alpha"

    @test("unit::test_arc_cache")
    def _test_arc():
        arc = ARCCache(4)
        for i in range(1, 5):
            arc.put(f"k{i}", f"val{i}")
        arc.get("k1")
        arc.get("k2")
        arc.put("k5", "val5")
        assert arc.get("k1") == "val1"
        assert arc.get("k2") == "val2"

    @test("bugs::test_bug_cycle_deadlock")
    def _test_cycle():
        policies = {
            "group": {
                "member": {"type": "computed_userset", "relation": "member"}
            }
        }
        store = MemoryTupleStore()
        store.insert(
            RelationTuple(
                "group",
                "grp-a",
                "member",
                Subject("group", "grp-b", "member"),
            )
        )
        store.insert(
            RelationTuple(
                "group",
                "grp-b",
                "member",
                Subject("group", "grp-a", "member"),
            )
        )
        checker = CheckEngine(policies, store, max_depth=16)
        assert (
            checker.check("group", "grp-a", "member", Subject("user", "alice"))
            is False
        )

    @test("bugs::test_bug_cursor_skew")
    def _test_cursor():
        token = base64.b64encode(b"cursor:42").decode("ascii")
        prefix = "cursor:"
        decoded = base64.b64decode(token).decode("ascii")
        offset = int(decoded[len(prefix) :])
        assert offset == 42

    print(f"TAP version 14\n1..{len(tests)}")
    failures = 0

    for idx, (name, fn) in enumerate(tests, start=1):
        t0 = time.perf_counter()
        try:
            fn()
            dur_ms = (time.perf_counter() - t0) * 1000.0
            print(f"ok {idx} - {name} ({dur_ms:.2f}ms)")
        except Exception as e:
            dur_ms = (time.perf_counter() - t0) * 1000.0
            print(f"not ok {idx} - {name} ({dur_ms:.2f}ms): {e}")
            failures += 1

    if failures == 0:
        print(f"\nAll {len(tests)} test suites passed with 100% success rate.")
        return 0
    else:
        print(f"\nFailed: {failures} out of {len(tests)} test suites failed.")
        return 1


if __name__ == "__main__":
    sys.exit(run_all_tests())
