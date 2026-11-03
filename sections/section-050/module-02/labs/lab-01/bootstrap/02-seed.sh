#!/usr/bin/env bash
set -euo pipefail

for n in team-a team-b; do kubectl create namespace $n --dry-run=client -o yaml | kubectl apply -f -; kubectl label namespace $n tier=standard --overwrite; done
kubectl create namespace scratch --dry-run=client -o yaml | kubectl apply -f -
cat <<'EOF' | kubectl apply -f -
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
EOF
