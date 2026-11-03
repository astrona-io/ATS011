#!/usr/bin/env bash
# Every container image must come from an approved registry
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

ensure_ns shop; need_policy; settle
printf 'apiVersion: apps/v1\nkind: Deployment\nmetadata:\n  name: mixed\n  namespace: shop\n  labels: {tier: backend}\nspec:\n  replicas: 1\n  selector:\n    matchLabels: {app: mixed}\n  template:\n    metadata:\n      labels: {app: mixed}\n    spec:\n      containers:\n        - name: a\n          image: ghcr.io/x/app:1\n        - name: b\n          image: docker.io/library/nginx:1.27\n' | expect_rejected "second container from docker.io"
printf 'apiVersion: apps/v1\nkind: Deployment\nmetadata:\n  name: fine\n  namespace: shop\n  labels: {tier: backend}\nspec:\n  replicas: 1\n  selector:\n    matchLabels: {app: fine}\n  template:\n    metadata:\n      labels: {app: fine}\n    spec:\n      containers:\n        - name: a\n          image: registry.example.com/x/app:1\n        - name: b\n          image: ghcr.io/x/side:1\n' | expect_admitted "both containers approved"

echo "RESULT: PASS"
exit 0
