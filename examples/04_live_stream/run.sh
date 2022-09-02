#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$DIR/../.."

echo "Running Axon Live Mutation Stream & Subscription Example..."
python3 "$ROOT/harness/runner.py"
echo "Live Stream Example completed."
