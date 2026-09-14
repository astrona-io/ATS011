#!/usr/bin/env bash
set -uo pipefail

NS="precondition-capstone-check"
EXEMPT_NS="trusted-automation"
FAIL=0

kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create ns "$NS" >/dev/null 2>&1
kubectl get ns "$EXEMPT_NS" >/dev/null 2>&1 || kubectl create ns "$EXEMPT_NS" >/dev/null 2>&1

if ! kubectl get clusterpolicy -o name 2>/dev/null | grep -q .; then
  echo "FAIL: no ClusterPolicy found on the cluster."
  exit 1
fi

echo "--- check 1: CREATE, no team label, non-exempt namespace -> must be REJECTED ---"
if kubectl run bad-create -n "$NS" --image=nginx --restart=Never 2>/tmp/err1; then
  echo "FAIL: a non-compliant Pod created in a non-exempt namespace was admitted."
  kubectl delete pod bad-create -n "$NS" --ignore-not-found >/dev/null 2>&1
  FAIL=1
else
  grep -qi "denied the request\|admission webhook" /tmp/err1 && echo "OK: rejected as expected." || { echo "FAIL: rejected, but not by an admission webhook."; cat /tmp/err1; FAIL=1; }
fi

echo "--- check 2: CREATE, no team label, EXEMPT namespace -> must be ADMITTED (all-of preconditions fails on namespace) ---"
if kubectl run auto-pod -n "$EXEMPT_NS" --image=nginx --restart=Never 2>/tmp/err2; then
  echo "OK: admitted as expected."
else
  echo "FAIL: a Pod created in the exempt namespace '$EXEMPT_NS' was rejected -- the namespace precondition did not skip the rule."
  cat /tmp/err2
  FAIL=1
fi

echo "--- check 3: CREATE, team label present, non-exempt namespace -> must be ADMITTED ---"
if kubectl run good-create -n "$NS" --image=nginx --restart=Never --labels=team=platform 2>/tmp/err3; then
  echo "OK: admitted as expected."
else
  echo "FAIL: a fully compliant Pod (team label set, CREATE, non-exempt ns) was rejected."
  cat /tmp/err3
  FAIL=1
fi

echo "--- check 4: UPDATE removing the team label from an existing compliant Pod -> must be ADMITTED (rule only fires on CREATE) ---"
if kubectl get pod good-create -n "$NS" >/dev/null 2>&1; then
  if kubectl label pod good-create -n "$NS" team- 2>/tmp/err4; then
    remaining="$(kubectl get pod good-create -n "$NS" -o jsonpath='{.metadata.labels.team}' 2>/dev/null)"
    if [ -z "$remaining" ]; then
      echo "OK: label removal via UPDATE was admitted as expected (operation precondition scoped the rule to CREATE only)."
    else
      echo "FAIL: the team label is still present after the update -- unexpected."
      FAIL=1
    fi
  else
    echo "FAIL: removing the team label via UPDATE was rejected -- the rule is not correctly scoped to CREATE only."
    cat /tmp/err4
    FAIL=1
  fi
else
  echo "FAIL: could not find good-create Pod from check 3 to run the UPDATE test against."
  FAIL=1
fi

kubectl delete pod bad-create good-create -n "$NS" --ignore-not-found >/dev/null 2>&1
kubectl delete pod auto-pod -n "$EXEMPT_NS" --ignore-not-found >/dev/null 2>&1
kubectl delete ns "$NS" --ignore-not-found >/dev/null 2>&1
kubectl delete ns "$EXEMPT_NS" --ignore-not-found >/dev/null 2>&1

if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
exit 0
