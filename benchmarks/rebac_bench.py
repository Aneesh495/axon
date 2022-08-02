#!/usr/bin/env python3
"""
Dedicated ReBAC Check Engine Benchmark.
Evaluates Zanzibar rule rewrite traversal under high concurrency.
"""

import sys
import time
from pathlib import Path

# Add harness to path
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "harness"))

from runner import CheckEngine, MemoryTupleStore, RelationTuple, Subject


def main():
    iterations = 50000
    if len(sys.argv) > 1 and sys.argv[1].isdigit():
        iterations = int(sys.argv[1])

    policies = {
        "document": {
            "owner": {"type": "this"},
            "editor": {
                "type": "union",
                "children": [
                    {"type": "this"},
                    {"type": "computed_userset", "relation": "owner"},
                ],
            },
            "viewer": {
                "type": "union",
                "children": [
                    {"type": "this"},
                    {"type": "computed_userset", "relation": "editor"},
                ],
            },
        }
    }

    store = MemoryTupleStore()
    alice = Subject("user", "alice")
    store.insert(RelationTuple("document", "doc-1", "owner", alice))

    checker = CheckEngine(policies, store)

    print(f"Executing {iterations} ReBAC check evaluations...")
    start = time.perf_counter()
    for _ in range(iterations):
        allowed = checker.check("document", "doc-1", "viewer", alice)
        if not allowed:
            print("Assertion failed during benchmark", file=sys.stderr)
            return 1
    duration = time.perf_counter() - start

    ops_per_sec = iterations / duration
    avg_us = (duration / iterations) * 1000000.0

    print(f"Completed {iterations} checks in {duration:.4f}s")
    print(f"Throughput: {ops_per_sec:,.2f} checks/sec")
    print(f"Average Latency: {avg_us:.3f} microseconds/check")
    return 0


if __name__ == "__main__":
    sys.exit(main())
