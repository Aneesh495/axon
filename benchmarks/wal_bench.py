#!/usr/bin/env python3
"""
Dedicated Write-Ahead Log (WAL) Serialization & Checksum Benchmark.
Measures binary framing rate and CRC32 verification throughput.
"""

import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "harness"))

from runner import ByteBuffer, CRC32


def main():
    iterations = 100000
    if len(sys.argv) > 1 and sys.argv[1].isdigit():
        iterations = int(sys.argv[1])

    print(f"Benchmarking WAL binary serialization and CRC32 framing ({iterations} entries)...")

    start = time.perf_counter()
    total_bytes = 0

    for i in range(iterations):
        bb = ByteBuffer()
        bb.write_int64_be(i + 1)  # LSN
        bb.write_int64_be(1609459200000 + i)  # Timestamp
        bb.write_uint8(1)  # PUT
        bb.write_string_prefixed("axon_documents")
        bb.write_string_prefixed(f"doc_{i}")
        bb.write_string_prefixed('{"title":"Distributed Graph Processing","version":1}')

        data = bb.raw()
        crc = CRC32.calculate(data)
        bb.write_uint32_be(crc)

        total_bytes += len(bb.raw())

    duration = time.perf_counter() - start
    ops_per_sec = iterations / duration
    mb_per_sec = (total_bytes / (1024 * 1024)) / duration

    print(f"Completed {iterations} WAL serializations in {duration:.4f}s")
    print(f"Throughput: {ops_per_sec:,.2f} frames/sec")
    print(f"Data Rate:  {mb_per_sec:.2f} MB/sec")
    return 0


if __name__ == "__main__":
    sys.exit(main())
