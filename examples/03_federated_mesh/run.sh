#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$DIR/../.."

echo "Running Axon Federated Supergraph Mesh Example..."
python3 "$ROOT/bin/axon" query '{ Document(id: "doc-1") { title } }'
echo "Federated Mesh Example executed successfully."
