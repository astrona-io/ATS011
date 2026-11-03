#!/usr/bin/env bash
# Changing the ConfigMap changes the outcome
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

ensure_ns ctx-lab; need_policy; settle
orig=$(kubectl get configmap limits -n policy-config -o jsonpath='{.data.max-replicas}')
kubectl patch configmap limits -n policy-config --type merge -p '{"data":{"max-replicas":"8"}}' >/dev/null
sleep 3
dep() { printf 'apiVersion: apps/v1\nkind: Deployment\nmetadata:\n  name: d%s\n  namespace: ctx-lab\nspec:\n  replicas: %s\n  selector:\n    matchLabels: {app: d%s}\n  template:\n    metadata:\n      labels: {app: d%s}\n    spec:\n      containers:\n        - name: app\n          image: nginx:1.27\n' "$1" "$1" "$1" "$1"; }
r1=$(dep 5 | kubectl apply --dry-run=server -f - >/dev/null 2>&1; echo $?)
r2=$(dep 9 | kubectl apply --dry-run=server -f - >/dev/null 2>&1; echo $?)
kubectl patch configmap limits -n policy-config --type merge -p "{\"data\":{\"max-replicas\":\"${orig:-3}\"}}" >/dev/null
[ "$r1" = "0" ] || fail "5 replicas must be admitted when the ConfigMap limit is 8."
[ "$r2" != "0" ] || fail "9 replicas must be rejected when the ConfigMap limit is 8."
ok "the outcome follows the ConfigMap."

echo "RESULT: PASS"
exit 0
