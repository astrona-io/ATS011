#!/usr/bin/env bash
# OS prep for the Background Scanning playground.
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

echo "[playground] Seeding pre-existing workloads in the 'legacy' namespace..."
# These are created BEFORE you write any policy, which is the whole point:
# they are what a rule written later has to deal with retroactively.
kubectl create namespace legacy --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: legacy-web
  namespace: legacy
spec:
  containers:
    - name: app
      image: nginx:1.27
---
apiVersion: v1
kind: Pod
metadata:
  name: legacy-cache
  namespace: legacy
  labels:
    team: platform
spec:
  containers:
    - name: app
      image: nginx:1.27
EOF
kubectl -n legacy wait --for=condition=Ready pod --all --timeout=180s || true

echo "[playground] Kyverno ${KYVERNO_VERSION} is ready. Two Pods already exist in the 'legacy'\n[playground] namespace, created before any policy -- background scanning's natural subject."
