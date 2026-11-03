#!/usr/bin/env bash
# A Pod may not use more than it requested
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

ensure_ns fn-lab; need_policy; settle
now_minus() { date -u -d "$1 hours ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-"$1"H +%Y-%m-%dT%H:%M:%SZ; }
# pod NAME OWNER CONFIG REQUESTED USED APPROVED -- every argument defaults to a valid value.
pod() {
  local name="${1:-web-01}" owner="${2:-platform/web}" config="${3:-cmVhZHk=}" req="${4:-10}" used="${5:-4}" appr="${6:-$(now_minus 1)}"
  printf 'apiVersion: v1\nkind: Pod\nmetadata:\n  name: %s\n  namespace: fn-lab\n  annotations:\n    owner: "%s"\n    config: "%s"\n    requested: "%s"\n    used: "%s"\n    approved: "%s"\nspec:\n  containers:\n    - name: app\n      image: nginx:1.27\n' "$name" "$owner" "$config" "$req" "$used" "$appr"
}
pod | expect_admitted "a fully valid Pod"
pod web-02 platform/web cmVhZHk= 4 10 | expect_rejected "used 10 of 4 requested"
pod web-03 platform/web cmVhZHk= 10 10 | expect_admitted "used 10 of 10 requested"
pod web-04 platform/web cmVhZHk= 100 9 | expect_admitted "used 9 of 100 requested (numeric, not string, comparison)"

echo "RESULT: PASS"
exit 0
