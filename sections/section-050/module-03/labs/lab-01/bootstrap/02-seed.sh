#!/usr/bin/env bash
set -euo pipefail

kubectl create namespace shared-config --dry-run=client -o yaml | kubectl apply -f -
kubectl -n shared-config create configmap app-settings --from-literal=log-level=info --dry-run=client -o yaml | kubectl apply -f -
kubectl -n shared-config create configmap feature-flags --from-literal=beta=off --dry-run=client -o yaml | kubectl apply -f -
kubectl -n shared-config create configmap private-notes --from-literal=note=internal --dry-run=client -o yaml | kubectl apply -f -
kubectl -n shared-config label configmap app-settings feature-flags share=true --overwrite
cat <<'YAML' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kyverno:background-controller:lab-configmaps
  labels:
    rbac.kyverno.io/aggregate-to-background-controller: "true"
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["create", "update", "delete", "get", "list", "watch"]
YAML
