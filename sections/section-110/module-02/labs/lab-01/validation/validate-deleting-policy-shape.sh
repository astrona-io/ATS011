#!/usr/bin/env bash
# The DeletingPolicy has a schedule and a guarded CEL condition on object
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

j=$(kubectl get deletingpolicy sweep-ephemeral -o json 2>/dev/null) || fail "no DeletingPolicy named sweep-ephemeral."
[ "$(echo "$j" | jq -r '.spec.schedule')" = "* * * * *" ] || fail "spec.schedule must be '* * * * *'."
[ "$(echo "$j" | jq -r '.spec.matchConstraints.resourceRules[0].resources[0]')" = "pods" ] || fail "matchConstraints must match the resource pods."
e=$(echo "$j" | jq -r '.spec.conditions[0].expression')
echo "$e" | grep -q 'has(object.metadata.labels)' || fail "the condition must be guarded with has(object.metadata.labels). Found: $e"
echo "$e" | grep -q 'lifecycle' || fail "the condition must test the lifecycle label. Found: $e"
echo "$e" | grep -q 'ephemeral' || fail "the condition must compare with ephemeral. Found: $e"
ok "the DeletingPolicy is shaped correctly."

echo "RESULT: PASS"
exit 0
