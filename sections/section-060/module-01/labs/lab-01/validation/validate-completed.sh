#!/usr/bin/env bash
set -uo pipefail

NS="verifyimage-check"
FAIL=0

kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create ns "$NS" >/dev/null 2>&1

if ! kubectl get clusterpolicy -o name 2>/dev/null | grep -q .; then
  echo "FAIL: no ClusterPolicy found on the cluster."
  exit 1
fi

echo "--- check 1: unsigned image must be REJECTED ---"
if kubectl run bad-unsigned -n "$NS" --image=ghcr.io/kyverno/test-verify-image:unsigned --restart=Never 2>/tmp/err1; then
  echo "FAIL: an unsigned image was admitted."
  kubectl delete pod bad-unsigned -n "$NS" --ignore-not-found >/dev/null 2>&1
  FAIL=1
else
  grep -qi "denied the request\|admission webhook" /tmp/err1 && echo "OK: rejected as expected." || { echo "FAIL: rejected, but not by an admission webhook."; cat /tmp/err1; FAIL=1; }
fi

echo "--- check 2: image signed with the WRONG key must be REJECTED ---"
if kubectl run bad-wrongkey -n "$NS" --image=ghcr.io/kyverno/test-verify-image:signed-by-someone-else --restart=Never 2>/tmp/err2; then
  echo "FAIL: an image signed with a mismatched key was admitted."
  kubectl delete pod bad-wrongkey -n "$NS" --ignore-not-found >/dev/null 2>&1
  FAIL=1
else
  grep -qi "denied the request\|admission webhook" /tmp/err2 && echo "OK: rejected as expected." || { echo "FAIL: rejected, but not by an admission webhook."; cat /tmp/err2; FAIL=1; }
fi

echo "--- check 3: an unrelated image outside the verified repository must be ADMITTED (the rule must be scoped, not global) ---"
if kubectl run unrelated -n "$NS" --image=nginx:1.25 --restart=Never 2>/tmp/err3; then
  echo "OK: admitted as expected (out of the rule's imageReferences scope)."
  kubectl delete pod unrelated -n "$NS" --ignore-not-found >/dev/null 2>&1
else
  echo "FAIL: an image outside the verified repository was rejected — the rule's imageReferences is scoped too broadly (e.g. '*' instead of the test-verify-image repo)."
  cat /tmp/err3
  FAIL=1
fi

echo "--- check 4: correctly signed image (matching public key) must be ADMITTED and digest-pinned ---"
if kubectl run good-signed -n "$NS" --image=ghcr.io/kyverno/test-verify-image:signed --restart=Never 2>/tmp/err4; then
  IMG=$(kubectl get pod good-signed -n "$NS" -o jsonpath='{.spec.containers[0].image}' 2>/dev/null)
  echo "Persisted image reference: $IMG"
  if echo "$IMG" | grep -q "@sha256:"; then
    echo "OK: admitted and mutated to an immutable digest reference."
  else
    echo "FAIL: admitted, but the image reference was not pinned to a digest."
    FAIL=1
  fi
  kubectl delete pod good-signed -n "$NS" --ignore-not-found >/dev/null 2>&1
else
  echo "FAIL: a correctly signed image (matching the policy's public key) was rejected."
  cat /tmp/err4
  FAIL=1
fi

kubectl delete ns "$NS" --ignore-not-found >/dev/null 2>&1

if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
exit 0
