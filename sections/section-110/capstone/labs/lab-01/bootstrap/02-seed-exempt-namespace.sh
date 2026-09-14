#!/usr/bin/env bash
set -euo pipefail

echo "Seeding the exempt namespace for the CEL capstone..."
kubectl create namespace cel-exempt --dry-run=client -o yaml | kubectl apply -f -

echo "Namespace ready: cel-exempt (must be skipped by the policy, not merely allowed by it)."
