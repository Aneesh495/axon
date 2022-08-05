#!/usr/bin/env python3
"""
Dedicated DataLoader Batch Coalescing Benchmark.
Measures batch dispatch efficiency and microtask queue overhead.
"""

import sys
import time


class MockBatchLoader:

    def __init__(self, batch_fn, batch_size=1024):
        self.batch_fn = batch_fn
        self.batch_size = batch_size
        self.queue = []
        self.cache = {}

    def load(self, key):
        if key in self.cache:
            return self.cache[key]
        self.queue.append(key)
        if len(self.queue) >= self.batch_size:
            self.dispatch()
        return None

    def dispatch(self):
        if not self.queue:
            return
        keys = self.queue
        self.queue = []
        res = self.batch_fn(keys)
        self.cache.update(res)


def main():
    iterations = 100000
    if len(sys.argv) > 1 and sys.argv[1].isdigit():
        iterations = int(sys.argv[1])

    batch_calls = 0

    def batch_fetch(keys):
        nonlocal batch_calls
        batch_calls += 1
        return {k: f"data_{k}" for k in keys}

    loader = MockBatchLoader(batch_fetch, batch_size=500)

    print(f"Loading {iterations} entities through DataLoader batch queue...")
    start = time.perf_counter()
    for i in range(iterations):
        loader.load(f"key_{i}")
    loader.dispatch()
    duration = time.perf_counter() - start

    ops_per_sec = iterations / duration
    print(f"Completed {iterations} entity loads in {duration:.4f}s")
    print(f"Total Underlying Batch Dispatches: {batch_calls}")
    print(
        f"Batching Factor: {iterations / max(1, batch_calls):.1f}x reduction"
        " in I/O roundtrips"
    )
    print(f"Throughput: {ops_per_sec:,.2f} entity loads/sec")
    return 0


if __name__ == "__main__":
    sys.exit(main())
