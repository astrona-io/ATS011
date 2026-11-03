#!/usr/bin/env bash
set -euo pipefail

KYVERNO_VERSION="v1.19.1"

echo "Installing Kyverno ${KYVERNO_VERSION}..."
kubectl apply --server-side -f "https://github.com/kyverno/kyverno/releases/download/${KYVERNO_VERSION}/install.yaml"

echo "Waiting for Kyverno controllers to become available..."
kubectl -n kyverno wait --for=condition=Available deployment --all --timeout=300s
kubectl -n kyverno wait --for=condition=Ready pod --all --timeout=300s

echo "Kyverno ${KYVERNO_VERSION} is ready."
