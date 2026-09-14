#!/usr/bin/env bash
set -euo pipefail

NS="legacy-apps"

echo "Creating namespace '${NS}' with Pods that predate any policy..."
kubectl create ns "$NS" --dry-run=client -o yaml | kubectl apply -f -

# A compliant Pod: already carries a non-empty team label.
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: legacy-compliant
  namespace: ${NS}
  labels:
    team: platform
spec:
  containers:
    - name: app
      image: nginx:1.25
EOF

# A non-compliant Pod: no team label at all.
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: legacy-noncompliant
  namespace: ${NS}
spec:
  containers:
    - name: app
      image: nginx:1.25
EOF

# A non-compliant Pod: the label key exists but its value is empty.
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: legacy-empty-team-label
  namespace: ${NS}
  labels:
    team: ""
spec:
  containers:
    - name: app
      image: nginx:1.25
EOF

echo "Waiting for the three legacy Pods to be Running..."
kubectl -n "$NS" wait --for=condition=Ready pod --all --timeout=120s

echo "Legacy Pods are running. No ClusterPolicy exists yet -- that is the point:"
kubectl get pods -n "$NS"
echo "No policy governs this namespace yet:"
kubectl get clusterpolicy 2>/dev/null || true
