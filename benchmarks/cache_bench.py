#!/usr/bin/env python3
"""
Dedicated Cache Eviction and Hit Ratio Benchmark.
Compares LRU vs ARC performance under zipfian and scan workloads.
"""

import random
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "harness"))

from runner import ARCCache, LRUCache


def main():
    capacity = 1000
    operations = 50000

    print(f"Comparing LRU vs ARC on {operations} operations (capacity={capacity})...")

    # Generate Zipfian-like distribution (frequent keys) mixed with scan bursts
    keys = [f"frequent_{i}" for i in range(200)]
    scan_keys = [f"scan_{i}" for i in range(10000)]

    workload = []
    for _ in range(operations):
        if random.random() < 0.80:
            workload.append(random.choice(keys))
        else:
            workload.append(random.choice(scan_keys))

    # Evaluate LRU
    lru = LRUCache(capacity)
    lru_hits = 0
    t0 = time.perf_counter()
    for k in workload:
        val = lru.get(k)
        if val is not None:
            lru_hits += 1
        else:
            lru.put(k, f"payload_{k}")
    lru_dur = time.perf_counter() - t0
    lru_ratio = (lru_hits / operations) * 100.0

    # Evaluate ARC
    arc = ARCCache(capacity)
    arc_hits = 0
    t1 = time.perf_counter()
    for k in workload:
        val = arc.get(k)
        if val is not None:
            arc_hits += 1
        else:
            arc.put(k, f"payload_{k}")
    arc_dur = time.perf_counter() - t1
    arc_ratio = (arc_hits / operations) * 100.0

    print("\n--- Cache Benchmark Results ---")
    print(f"LRU: Hit Ratio = {lru_ratio:.2f}%, Throughput = {operations / lru_dur:,.2f} ops/sec")
    print(f"ARC: Hit Ratio = {arc_ratio:.2f}%, Throughput = {operations / arc_dur:,.2f} ops/sec")
    print("-------------------------------\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
