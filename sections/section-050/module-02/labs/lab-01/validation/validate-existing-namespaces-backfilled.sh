#!/usr/bin/env bash
# team-a and team-b receive the ConfigMap, scratch does not
set -uo pipefail

fail() { echo "FAIL: $*"; echo "RESULT: FAIL"; exit 1; }
ok() { echo "OK: $*"; }
ensure_ns() { kubectl get ns "$1" >/dev/null 2>&1 || kubectl create ns "$1" >/dev/null 2>&1; }
# Give the Kyverno webhooks a moment to pick up a freshly applied policy.
settle() { kubectl wait --for=condition=Ready clusterpolicy --all --timeout=60s >/dev/null 2>&1 || true; sleep 5; }
# Reads YAML on stdin. Passes when Kyverno rejects the object.
expect_rejected() {
  local yaml err; yaml=$(cat)
  if err=$(printf '%s\n' "$yaml" | kubectl apply --dry-run=server -f - 2>&1); then
    fail "$1: the object was admitted but must be rejected."
  fi
  echo "$err" | grep -qi "denied the request\|admission webhook\|blocked due to" || fail "$1: rejected, but not by a Kyverno admission webhook: $err"
  ok "$1: rejected as expected."
}
# Reads YAML on stdin. Passes when the object is admitted.
expect_admitted() {
  local yaml err; yaml=$(cat)
  err=$(printf '%s\n' "$yaml" | kubectl apply --dry-run=server -f - 2>&1) || fail "$1: the object was rejected but must be admitted: $err"
  ok "$1: admitted as expected."
}
# Reads YAML on stdin. Prints the object as the API server would store it (after mutation).
admitted_json() {
  local yaml; yaml=$(cat)
  printf '%s\n' "$yaml" | kubectl apply --dry-run=server -o json -f - 2>&1
}
need_policy() {
  kubectl get clusterpolicy,policy -A -o name 2>/dev/null | grep -q . || fail "no Kyverno policy found on the cluster."
}

kubectl get clusterpolicy standard-defaults >/dev/null 2>&1 || fail "no ClusterPolicy named standard-defaults."
for ns in team-a team-b; do
  found=""
  for i in $(seq 1 24); do
    if kubectl get configmap platform-defaults -n "$ns" >/dev/null 2>&1; then found=yes; break; fi
    sleep 5
  done
  [ -n "$found" ] || fail "ConfigMap platform-defaults was not generated in $ns within 2 minutes."
  v=$(kubectl get configmap platform-defaults -n "$ns" -o jsonpath='{.data.log-level}')
  [ "$v" = "info" ] || fail "platform-defaults in $ns has log-level '$v', expected info."
  ok "$ns has platform-defaults."
done
kubectl get configmap platform-defaults -n scratch >/dev/null 2>&1 && fail "scratch must not receive the ConfigMap."
ok "scratch has no ConfigMap."

echo "RESULT: PASS"
exit 0
