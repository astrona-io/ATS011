#!/usr/bin/env bash
set -euo pipefail

NS="team-a"

echo "Creating namespace '${NS}' with two Pods already running..."
kubectl create ns "$NS" --dry-run=client -o yaml | kubectl apply -f -

kubectl run seed-1 -n "$NS" --image=nginx --restart=Never
kubectl run seed-2 -n "$NS" --image=nginx --restart=Never

echo "Waiting for the seed Pods to be Running..."
kubectl -n "$NS" wait --for=condition=Ready pod --all --timeout=120s

echo "Namespace '${NS}' is seeded with 2 Pods. No ClusterPolicy exists yet:"
kubectl get pods -n "$NS"
kubectl get clusterpolicy 2>/dev/null || true
