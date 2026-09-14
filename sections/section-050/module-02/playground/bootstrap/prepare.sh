#!/usr/bin/env bash
# OS prep for the Generating for What Already Exists playground.
# Environment preparation only: install Kyverno and wait for its controllers.
# There is no task and no grading here -- this just gives you a cluster with a
# working admission controller so you can write policies and watch them fire.
set -euo pipefail

KYVERNO_VERSION="v1.19.1"

echo "[playground] Installing Kyverno ${KYVERNO_VERSION}..."
# Server-side apply is required: a plain apply of this manifest fails with
# 'metadata.annotations: Too long' on the Kyverno CRDs.
kubectl apply --server-side -f "https://github.com/kyverno/kyverno/releases/download/${KYVERNO_VERSION}/install.yaml"

echo "[playground] Waiting for Kyverno controllers to become available..."
kubectl -n kyverno wait --for=condition=Available deployment --all --timeout=300s
kubectl -n kyverno wait --for=condition=Ready pod --all --timeout=300s

echo "[playground] Seeding namespaces that predate any policy you will write..."
for ns in legacy-a legacy-b; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

echo "[playground] Kyverno ${KYVERNO_VERSION} is ready. No policies are installed --"
echo "[playground] every rule that fires is one you wrote."
