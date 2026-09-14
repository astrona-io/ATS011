#!/usr/bin/env bash
set -uo pipefail

LEGACY_NS="legacy-apps"
CHECK_NS="bg-audit-check"
FAIL=0

report_has_result () {
  # report_has_result <namespace> <resource-name> <result-value>
  local ns="$1" name="$2" want="$3"
  kubectl get policyreport -n "$ns" -o json 2>/dev/null | jq -e \
    --arg name "$name" --arg want "$want" \
    '[.items[] | select(.scope.name == $name) | .results[]? | select(.result == $want)] | length > 0' \
    >/dev/null 2>&1
}

echo "--- check 1: a ClusterPolicy exists ---"
if ! kubectl get clusterpolicy -o name 2>/dev/null | grep -q .; then
  echo "FAIL: no ClusterPolicy found on the cluster."
  exit 1
fi
echo "OK: at least one ClusterPolicy exists."

echo "--- check 2: the three legacy Pods (created before the policy) are still running ---"
for pod in legacy-compliant legacy-noncompliant legacy-empty-team-label; do
  phase=$(kubectl get pod "$pod" -n "$LEGACY_NS" -o jsonpath='{.status.phase}' 2>/dev/null)
  if [ "$phase" != "Running" ]; then
    echo "FAIL: legacy Pod '$pod' is not Running (phase='$phase'). Background scans must never delete or block existing resources."
    FAIL=1
  else
    echo "OK: '$pod' is still Running, untouched by the scan."
  fi
done

echo "--- check 3: the policy runs in Audit mode (a NEW non-compliant Pod must be admitted, not blocked) ---"
kubectl create ns "$CHECK_NS" >/dev/null 2>&1
if kubectl run audit-mode-probe -n "$CHECK_NS" --image=nginx:1.25 --restart=Never 2>/tmp/err-audit; then
  echo "OK: a fresh non-compliant Pod was admitted -- the policy is Audit, not Enforce."
  kubectl delete pod audit-mode-probe -n "$CHECK_NS" --ignore-not-found >/dev/null 2>&1
else
  echo "FAIL: a fresh non-compliant Pod was rejected. This lab requires Audit mode (validationFailureAction/failureAction must not be Enforce)."
  cat /tmp/err-audit
  FAIL=1
fi
kubectl delete ns "$CHECK_NS" --ignore-not-found >/dev/null 2>&1

echo "--- check 4: background scan reaches back and reports on Pods that predate the policy ---"
echo "Polling PolicyReport entries in namespace '${LEGACY_NS}' (background scans are periodic, not instant)..."

FOUND_NONCOMPLIANT_FAIL=0
FOUND_EMPTY_LABEL_FAIL=0
FOUND_COMPLIANT_PASS=0

for i in $(seq 1 30); do
  if [ "$FOUND_NONCOMPLIANT_FAIL" -eq 0 ] && report_has_result "$LEGACY_NS" "legacy-noncompliant" "fail"; then
    FOUND_NONCOMPLIANT_FAIL=1
  fi
  if [ "$FOUND_EMPTY_LABEL_FAIL" -eq 0 ] && report_has_result "$LEGACY_NS" "legacy-empty-team-label" "fail"; then
    FOUND_EMPTY_LABEL_FAIL=1
  fi
  if [ "$FOUND_COMPLIANT_PASS" -eq 0 ] && report_has_result "$LEGACY_NS" "legacy-compliant" "pass"; then
    FOUND_COMPLIANT_PASS=1
  fi

  if [ "$FOUND_NONCOMPLIANT_FAIL" -eq 1 ] && [ "$FOUND_EMPTY_LABEL_FAIL" -eq 1 ] && [ "$FOUND_COMPLIANT_PASS" -eq 1 ]; then
    break
  fi
  sleep 5
done

if [ "$FOUND_NONCOMPLIANT_FAIL" -eq 1 ]; then
  echo "OK: 'legacy-noncompliant' (no team label, pre-existing) has a 'fail' result in its PolicyReport."
else
  echo "FAIL: no 'fail' result found for 'legacy-noncompliant' -- the background scan never reached this pre-existing Pod."
  FAIL=1
fi

if [ "$FOUND_EMPTY_LABEL_FAIL" -eq 1 ]; then
  echo "OK: 'legacy-empty-team-label' (empty team label, pre-existing) has a 'fail' result in its PolicyReport."
else
  echo "FAIL: no 'fail' result found for 'legacy-empty-team-label'."
  FAIL=1
fi

if [ "$FOUND_COMPLIANT_PASS" -eq 1 ]; then
  echo "OK: 'legacy-compliant' (pre-existing, already had a team label) has a 'pass' result in its PolicyReport."
else
  echo "FAIL: no 'pass' result found for 'legacy-compliant'."
  FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
exit 0
