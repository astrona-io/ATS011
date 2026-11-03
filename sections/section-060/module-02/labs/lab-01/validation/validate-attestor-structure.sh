#!/usr/bin/env bash
# The policy has one attestor set with count 1 and two key entries
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

j=$(kubectl get clusterpolicy verify-release-images -o json 2>/dev/null) || fail "no ClusterPolicy named verify-release-images."
v='.spec.rules[0].verifyImages[0]'
[ "$(echo "$j" | jq -r "$v.imageReferences[0]")" = "registry.example.com/release/*" ] || fail "imageReferences[0] is not registry.example.com/release/*."
[ "$(echo "$j" | jq -r "$v.attestors | length")" = "1" ] || fail "expected exactly one attestor set."
[ "$(echo "$j" | jq -r "$v.attestors[0].count")" = "1" ] || fail "attestors[0].count must be 1."
[ "$(echo "$j" | jq -r "$v.attestors[0].entries | length")" = "2" ] || fail "expected two attestor entries."
n=$(echo "$j" | jq -r "[$v.attestors[0].entries[] | select(.keys.publicKeys != null)] | length")
[ "$n" = "2" ] || fail "both entries must use keys.publicKeys."
ok "attestor structure is correct."

echo "RESULT: PASS"
exit 0
