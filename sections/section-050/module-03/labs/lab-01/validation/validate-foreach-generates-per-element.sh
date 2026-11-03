#!/usr/bin/env bash
# one ConfigMap per list element, legacy skipped
set -uo pipefail

fail() { echo "FAIL: $*"; echo "RESULT: FAIL"; exit 1; }
ok() { echo "OK: $*"; }

kubectl get clusterpolicy env-configmaps >/dev/null 2>&1 || fail "no ClusterPolicy named env-configmaps."
ns="lab-env-$RANDOM"
printf "apiVersion: v1\nkind: Namespace\nmetadata:\n  name: %s\n  labels:\n    env-set: \"true\"\n  annotations:\n    envs: \"dev,test,legacy\"\n" "$ns" | kubectl apply -f - >/dev/null
missing=""
for e in dev test; do
  found=""
  for i in $(seq 1 24); do
    if kubectl get configmap "env-$e" -n "$ns" >/dev/null 2>&1; then found=yes; break; fi
    sleep 5
  done
  [ -n "$found" ] || missing="$missing env-$e"
done
vdev=$(kubectl get configmap env-dev -n "$ns" -o jsonpath='{.data.environment}' 2>/dev/null)
legacy=""
kubectl get configmap env-legacy -n "$ns" >/dev/null 2>&1 && legacy=yes
kubectl delete namespace "$ns" --wait=false >/dev/null 2>&1
[ -z "$missing" ] || fail "not generated within 2 minutes:$missing."
[ "$vdev" = "dev" ] || fail "env-dev has environment '$vdev', expected dev."
[ -z "$legacy" ] || fail "env-legacy was generated but legacy must be skipped."
ok "env-dev and env-test were generated, env-legacy was skipped."
echo "RESULT: PASS"
exit 0
