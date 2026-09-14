#!/usr/bin/env bash
set -uo pipefail

NS="precondition-check"
FAIL=0

kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create ns "$NS" >/dev/null 2>&1

if ! kubectl get clusterpolicy -o name 2>/dev/null | grep -q .; then
  echo "FAIL: no ClusterPolicy found on the cluster."
  exit 1
fi

echo "--- check 1: Pod with no team label and no exemption signal must be REJECTED ---"
if kubectl run bad-no-label -n "$NS" --image=nginx --restart=Never 2>/tmp/err1; then
  echo "FAIL: a non-compliant Pod with no exemption was admitted."
  kubectl delete pod bad-no-label -n "$NS" --ignore-not-found >/dev/null 2>&1
  FAIL=1
else
  grep -qi "denied the request\|admission webhook" /tmp/err1 && echo "OK: rejected as expected." || { echo "FAIL: rejected, but not by an admission webhook."; cat /tmp/err1; FAIL=1; }
fi

echo "--- check 2: Pod with no team label BUT tier: exempt must be ADMITTED (precondition skips the rule) ---"
if kubectl run exempt-pod -n "$NS" --image=nginx --restart=Never --labels=tier=exempt 2>/tmp/err2; then
  echo "OK: admitted as expected."
  kubectl delete pod exempt-pod -n "$NS" --ignore-not-found >/dev/null 2>&1
else
  echo "FAIL: a Pod labeled tier=exempt was rejected -- the precondition did not skip the rule."
  cat /tmp/err2
  FAIL=1
fi

echo "--- check 3: compliant Pod (has team label, no exemption) must still be ADMITTED ---"
if kubectl run good-pod -n "$NS" --image=nginx --restart=Never --labels=team=platform 2>/tmp/err3; then
  echo "OK: admitted as expected."
  kubectl delete pod good-pod -n "$NS" --ignore-not-found >/dev/null 2>&1
else
  echo "FAIL: a fully compliant Pod (team label set) was rejected -- the rule appears to always block."
  cat /tmp/err3
  FAIL=1
fi

kubectl delete ns "$NS" --ignore-not-found >/dev/null 2>&1

if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
exit 0
