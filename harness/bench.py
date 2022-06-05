#!/usr/bin/env python3
"""
Axon High-Concurrency Synthetic Benchmark Suite.
Measures throughput, p50, p90, p99, p99.9 latency percentiles for ReBAC and Caching.
"""

import sys
import time
from runner import CheckEngine, MemoryTupleStore, RelationTuple, Subject


def run_rebac_benchmark(iterations: int = 100000):
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
    store.insert(RelationTuple("workspace", "ws-1", "owner", alice))
    store.insert(
        RelationTuple(
            "document", "doc-1", "parent_workspace", Subject("workspace", "ws-1")
        )
    )

    checker = CheckEngine(policies, store)

    print(f"Executing {iterations} ReBAC checks...")
    latencies = []

    t_start = time.perf_counter()
    for _ in range(iterations):
        t0 = time.perf_counter()
        allowed = checker.check("document", "doc-1", "viewer", alice)
        t1 = time.perf_counter()
        if not allowed:
            print("Assertion failed during benchmark", file=sys.stderr)
            return 1
        latencies.append((t1 - t0) * 1000000.0)  # microseconds

    t_total = time.perf_counter() - t_start
    throughput = iterations / t_total

    latencies.sort()
    p50 = latencies[int(iterations * 0.50)]
    p90 = latencies[int(iterations * 0.90)]
    p99 = latencies[int(iterations * 0.99)]
    p999 = latencies[int(iterations * 0.999)]

    print("\n================ Benchmark Results ================")
    print(f"Iterations:        {iterations}")
    print(f"Total Duration:    {t_total:.4f} seconds")
    print(f"Throughput:        {throughput:,.2f} checks/sec")
    print(f"Latency p50:       {p50:.3f} microseconds")
    print(f"Latency p90:       {p90:.3f} microseconds")
    print(f"Latency p99:       {p99:.3f} microseconds")
    print(f"Latency p99.9:     {p999:.3f} microseconds")
    print("===================================================\n")
    return 0


def main():
    iterations = 100000
    if len(sys.argv) > 1 and sys.argv[1].isdigit():
        iterations = int(sys.argv[1])
    return run_rebac_benchmark(iterations)


if __name__ == "__main__":
    sys.exit(main())
