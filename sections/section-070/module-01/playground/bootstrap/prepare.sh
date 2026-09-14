#!/usr/bin/env bash
# OS prep for the Variables & API Calls in Policies playground.
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

echo "[playground] Seeding Pods in the 'team-a' namespace for context lookups..."
# Something for an apiCall to actually count. Three Pods, no policy anywhere.
kubectl create namespace team-a --dry-run=client -o yaml | kubectl apply -f -
for i in 1 2 3; do
  kubectl -n team-a run "workload-$i" --image=nginx:1.27 --restart=Never \
    --labels="team=a" >/dev/null 2>&1 || true
done
kubectl -n team-a wait --for=condition=Ready pod --all --timeout=180s || true

echo "[playground] Kyverno ${KYVERNO_VERSION} is ready. Three Pods already run in the 'team-a'\n[playground] namespace so a context.apiCall has something real to count."
