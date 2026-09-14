#!/usr/bin/env bash
set -euo pipefail

echo "Granting kyverno-background-controller permission to update Pods..."
echo "(required by mutate.mutateExistingOnPolicyUpdate + mutate.targets -- Kyverno's own"
echo " policy-validating webhook performs an auth check for this at policy-apply time)"

cat <<'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kyverno-background-controller-pods
  labels:
    rbac.kyverno.io/aggregate-to-background-controller: "true"
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch", "update", "patch"]
EOF

echo "Waiting for the grant to aggregate into kyverno:background-controller..."
for i in $(seq 1 30); do
  if kubectl get clusterrole kyverno:background-controller -o jsonpath='{.rules}' 2>/dev/null | grep -q '"pods"'; then
    echo "Aggregation confirmed."
    exit 0
  fi
  sleep 2
done

echo "WARNING: aggregation not confirmed within timeout, continuing anyway."
