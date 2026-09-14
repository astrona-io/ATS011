#!/usr/bin/env bash
set -euo pipefail

NS="legacy-workloads"

echo "Creating namespace '${NS}' with Pods that predate any policy..."
kubectl create ns "$NS" --dry-run=client -o yaml | kubectl apply -f -

# Missing the managed-by label entirely.
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: legacy-pod-a
  namespace: ${NS}
spec:
  containers:
    - name: app
      image: nginx:1.25
EOF

# Carries a managed-by label, but with the wrong value.
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: legacy-pod-b
  namespace: ${NS}
  labels:
    managed-by: legacy-team
spec:
  containers:
    - name: app
      image: nginx:1.25
EOF

echo "Waiting for the two legacy Pods to be Running..."
kubectl -n "$NS" wait --for=condition=Ready pod --all --timeout=120s

echo "Legacy Pods are running. No ClusterPolicy exists yet:"
kubectl get pods -n "$NS" --show-labels
kubectl get clusterpolicy 2>/dev/null || true
