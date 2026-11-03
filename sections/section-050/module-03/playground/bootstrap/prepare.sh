#!/usr/bin/env bash
# OS prep for the Cloning Several Resources and generate foreach playground.
# Environment preparation only: install Kyverno, allow the background controller
# to manage ConfigMaps and Secrets, and seed a source namespace to clone from.
set -euo pipefail

KYVERNO_VERSION="v1.19.1"

echo "[playground] Installing Kyverno ${KYVERNO_VERSION}..."
# Server-side apply is required: a plain apply of this manifest fails with
# 'metadata.annotations: Too long' on the Kyverno CRDs.
kubectl apply --server-side -f "https://github.com/kyverno/kyverno/releases/download/${KYVERNO_VERSION}/install.yaml"

echo "[playground] Waiting for Kyverno controllers to become available..."
kubectl -n kyverno wait --for=condition=Available deployment --all --timeout=300s
kubectl -n kyverno wait --for=condition=Ready pod --all --timeout=300s

echo "[playground] Letting the background controller manage ConfigMaps and Secrets..."
cat <<'YAML' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kyverno:background-controller:playground-generate
  labels:
    rbac.kyverno.io/aggregate-to-background-controller: "true"
rules:
  - apiGroups: [""]
    resources: ["configmaps", "secrets"]
    verbs: ["create", "update", "delete", "get", "list", "watch"]
YAML

echo "[playground] Seeding the source namespace 'shared-config'..."
kubectl create namespace shared-config --dry-run=client -o yaml | kubectl apply -f -
kubectl -n shared-config create configmap app-settings --from-literal=log-level=info --dry-run=client -o yaml | kubectl apply -f -
kubectl -n shared-config create configmap feature-flags --from-literal=beta=off --dry-run=client -o yaml | kubectl apply -f -
kubectl -n shared-config create configmap private-notes --from-literal=note=internal --dry-run=client -o yaml | kubectl apply -f -
kubectl -n shared-config label configmap app-settings feature-flags share=true --overwrite
kubectl -n shared-config create secret generic registry-auth --from-literal=user=demo --dry-run=client -o yaml | kubectl apply -f -
kubectl -n shared-config label secret registry-auth share=true --overwrite

echo "[playground] Kyverno ${KYVERNO_VERSION} is ready. No policies are installed --"
echo "[playground] every rule that fires is one you wrote."
