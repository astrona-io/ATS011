#!/usr/bin/env bash
# A container without a memory limit is rejected
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

ensure_ns assert-lab; need_policy; settle
printf 'apiVersion: v1\nkind: Pod\nmetadata:\n  name: nolimit\n  namespace: assert-lab\nspec:\n  serviceAccountName: app-sa\n  containers:\n    - name: app\n      image: nginx:1.27\n' | expect_rejected "Pod without a memory limit"
printf 'apiVersion: v1\nkind: Pod\nmetadata:\n  name: cpu-only\n  namespace: assert-lab\nspec:\n  serviceAccountName: app-sa\n  containers:\n    - name: app\n      image: nginx:1.27\n      resources:\n        limits:\n          cpu: 100m\n' | expect_rejected "Pod with a CPU limit but no memory limit"
printf 'apiVersion: v1\nkind: Pod\nmetadata:\n  name: limited\n  namespace: assert-lab\nspec:\n  serviceAccountName: app-sa\n  containers:\n    - name: app\n      image: nginx:1.27\n      resources:\n        limits:\n          memory: 128Mi\n' | expect_admitted "Pod with a memory limit"

echo "RESULT: PASS"
exit 0
