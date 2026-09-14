#!/usr/bin/env bash
set -euo pipefail

NS="legacy-services"

echo "Creating namespace '${NS}' with Pods that predate any policy..."
kubectl create ns "$NS" --dry-run=client -o yaml | kubectl apply -f -

# Fully compliant: has a team label, pinned image tag.
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: legacy-svc-compliant
  namespace: ${NS}
  labels:
    team: platform
spec:
  containers:
    - name: app
      image: nginx:1.25
EOF

# Missing the team label entirely.
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: legacy-svc-noncompliant
  namespace: ${NS}
spec:
  containers:
    - name: app
      image: nginx:1.25
EOF

# Has a team label, but was left running an unpinned ':latest' image
# since before anyone thought to write a policy about it.
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: legacy-svc-latest-tag
  namespace: ${NS}
  labels:
    team: platform
spec:
  containers:
    - name: app
      image: nginx:latest
EOF

echo "Waiting for the three legacy Pods to be Running..."
kubectl -n "$NS" wait --for=condition=Ready pod --all --timeout=120s

echo "Legacy Pods are running. No ClusterPolicy exists yet:"
kubectl get pods -n "$NS"
kubectl get clusterpolicy 2>/dev/null || true
