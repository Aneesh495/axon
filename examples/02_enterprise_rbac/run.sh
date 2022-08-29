#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$DIR/../.."

echo "Running Axon Enterprise Multi-Tenant RBAC Example..."
python3 "$ROOT/bin/axon" check workspace ws-infra member user:alice
echo "Enterprise RBAC Example verified successfully."
