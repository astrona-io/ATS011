#!/usr/bin/env bash
set -euo pipefail

KYVERNO_VERSION="v1.19.1"

echo "Installing Kyverno ${KYVERNO_VERSION}..."
kubectl apply --server-side -f "https://github.com/kyverno/kyverno/releases/download/${KYVERNO_VERSION}/install.yaml"

echo "Waiting for Kyverno controllers to become available..."
kubectl -n kyverno wait --for=condition=Available deployment --all --timeout=300s
kubectl -n kyverno wait --for=condition=Ready pod --all --timeout=300s

echo "Kyverno ${KYVERNO_VERSION} is ready."

echo "Creating the central 'platform-config' namespace and its source ConfigMap 'shared-ca'..."
kubectl create namespace platform-config --dry-run=client -o yaml | kubectl apply -f -
kubectl create configmap shared-ca \
  --from-literal=ca.crt="PLATFORM-ROOT-CA-V1" \
  -n platform-config \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Source ConfigMap ready:"
kubectl get configmap shared-ca -n platform-config -o jsonpath='{.data.ca\.crt}'
echo
