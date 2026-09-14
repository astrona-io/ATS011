#!/usr/bin/env bash
set -uo pipefail

FAIL=0

if ! kubectl get clusterpolicy -o name 2>/dev/null | grep -q .; then
  echo "FAIL: no ClusterPolicy found on the cluster."
  exit 1
fi

if ! kubectl get ns cap-a >/dev/null 2>&1; then
  echo "FAIL: namespace 'cap-a' (seeded by bootstrap) is missing."
  exit 1
fi

existing_a=$(kubectl get pods -n cap-a --no-headers 2>/dev/null | wc -l | tr -d ' ')
echo "--- cap-a currently has ${existing_a} Pod(s) (bootstrap seeds 2) ---"

echo "--- check 1: cap-a's 3rd Pod (count ${existing_a} < 3) must be ADMITTED ---"
if kubectl run grade-cap-third -n cap-a --image=nginx --restart=Never 2>/tmp/err1; then
  echo "OK: admitted as expected."
else
  echo "FAIL: a Pod that should have kept cap-a at or under the 3-Pod limit was rejected."
  cat /tmp/err1
  FAIL=1
fi

echo "--- check 2: cap-a's 4th Pod (count now 3) must be REJECTED, and the message must name it ---"
if kubectl run grade-cap-fourth -n cap-a --image=nginx --restart=Never 2>/tmp/err2; then
  echo "FAIL: a Pod that should have pushed cap-a over the 3-Pod limit was admitted."
  kubectl delete pod grade-cap-fourth -n cap-a --ignore-not-found >/dev/null 2>&1
  FAIL=1
else
  if grep -qi "denied the request\|admission webhook" /tmp/err2; then
    echo "OK: rejected as expected."
  else
    echo "FAIL: rejected, but not by an admission webhook."
    cat /tmp/err2
    FAIL=1
  fi
  if grep -q "grade-cap-fourth" /tmp/err2; then
    echo "OK: rejection message named the actual offending Pod (context.variable is real, not a generic message)."
  else
    echo "FAIL: rejection message did not contain the Pod's own name 'grade-cap-fourth' -- context.variable does not appear to be wired into the message."
    cat /tmp/err2
    FAIL=1
  fi
fi

echo "--- check 3: a brand-new namespace starts at 0 and independently allows 3, rejects the 4th (named) ---"
kubectl create ns cap-b >/dev/null 2>&1 || true

for i in 1 2 3; do
  if ! kubectl run "grade-capb-${i}" -n cap-b --image=nginx --restart=Never 2>/tmp/errb; then
    echo "FAIL: Pod #${i} in fresh namespace cap-b was rejected but should have been admitted (count was $((i-1)), limit is 3)."
    cat /tmp/errb
    FAIL=1
  fi
done
echo "OK: cap-b admitted its first 3 Pods (if no FAIL was printed above)."

if kubectl run grade-capb-breaker -n cap-b --image=nginx --restart=Never 2>/tmp/errb4; then
  echo "FAIL: cap-b's 4th Pod was admitted; the quota did not correctly count this fresh namespace's own live Pod total."
  kubectl delete pod grade-capb-breaker -n cap-b --ignore-not-found >/dev/null 2>&1
  FAIL=1
else
  if grep -qi "denied the request\|admission webhook" /tmp/errb4; then
    echo "OK: rejected as expected."
  else
    echo "FAIL: rejected, but not by an admission webhook."
    cat /tmp/errb4
    FAIL=1
  fi
  if grep -q "grade-capb-breaker" /tmp/errb4; then
    echo "OK: rejection message named the actual offending Pod in the second namespace too."
  else
    echo "FAIL: rejection message did not contain the Pod's own name 'grade-capb-breaker' in namespace cap-b."
    cat /tmp/errb4
    FAIL=1
  fi
fi

echo "--- cleanup ---"
kubectl delete pod grade-cap-third -n cap-a --ignore-not-found >/dev/null 2>&1
# --wait=false: a submitted policy that (incorrectly) still matches DELETE can make an
# over-limit namespace's own Pods undeletable, which would otherwise hang this cleanup.
kubectl delete ns cap-b --ignore-not-found --wait=false >/dev/null 2>&1

if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
exit 0
