#!/usr/bin/env bash
# labelled namespace gets the two shared ConfigMaps only
set -uo pipefail

fail() { echo "FAIL: $*"; echo "RESULT: FAIL"; exit 1; }
ok() { echo "OK: $*"; }

kubectl get clusterpolicy share-config >/dev/null 2>&1 || fail "no ClusterPolicy named share-config."
ns="lab-clone-$RANDOM"
printf "apiVersion: v1\nkind: Namespace\nmetadata:\n  name: %s\n  labels:\n    needs-shared: \"true\"\n" "$ns" | kubectl apply -f - >/dev/null
missing=""
for cm in app-settings feature-flags; do
  found=""
  for i in $(seq 1 24); do
    if kubectl get configmap "$cm" -n "$ns" >/dev/null 2>&1; then found=yes; break; fi
    sleep 5
  done
  [ -n "$found" ] || missing="$missing $cm"
done
private=""
kubectl get configmap private-notes -n "$ns" >/dev/null 2>&1 && private=yes
kubectl delete namespace "$ns" --wait=false >/dev/null 2>&1
[ -z "$missing" ] || fail "not cloned within 2 minutes:$missing."
[ -z "$private" ] || fail "private-notes was cloned but has no share label."
ok "app-settings and feature-flags were cloned, private-notes was not."
echo "RESULT: PASS"
exit 0
