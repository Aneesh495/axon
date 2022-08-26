#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$DIR/../.."

echo "Running Axon Social Network Example..."
python3 "$ROOT/bin/axon" check post pst-101 viewer user:alice
echo "Social Network Example completed successfully."
