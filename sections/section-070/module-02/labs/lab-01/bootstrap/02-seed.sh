#!/usr/bin/env bash
set -euo pipefail

kubectl create namespace policy-config --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace ctx-lab --dry-run=client -o yaml | kubectl apply -f -
kubectl create configmap limits -n policy-config --from-literal=max-replicas=3 --dry-run=client -o yaml | kubectl apply -f -
