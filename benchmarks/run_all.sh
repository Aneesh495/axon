#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$DIR/.."

echo "=========================================================="
echo "          Axon Comprehensive Benchmark Suite              "
echo "=========================================================="

echo -e "\n[1/4] Running ReBAC Userset Evaluation Benchmark..."
python3 "$DIR/rebac_bench.py" 50000

echo -e "\n[2/4] Running DataLoader Batch Coalescing Benchmark..."
python3 "$DIR/dataloader_bench.py" 50000

echo -e "\n[3/4] Running Multi-Tier Cache Eviction Benchmark..."
python3 "$DIR/cache_bench.py"

echo -e "\n[4/4] Running Write-Ahead Log Framing Benchmark..."
python3 "$DIR/wal_bench.py" 50000

echo -e "\n=========================================================="
echo "           All Performance Benchmarks Completed           "
echo "=========================================================="
