#!/usr/bin/env bash
set -uo pipefail

NS="legacy-services"
CHECK_NS="bg-capstone-audit-check"
FAIL=0

report_has_result () {
  # report_has_result <namespace> <resource-name> <result-value>
  local ns="$1" name="$2" want="$3"
  kubectl get policyreport -n "$ns" -o json 2>/dev/null | jq -e \
    --arg name "$name" --arg want "$want" \
    '[.items[] | select(.scope.name == $name) | .results[]? | select(.result == $want)] | length > 0' \
    >/dev/null 2>&1
}

report_result_count () {
  # report_result_count <namespace> <resource-name> <result-value>
  local ns="$1" name="$2" want="$3"
  kubectl get policyreport -n "$ns" -o json 2>/dev/null | jq \
    --arg name "$name" --arg want "$want" \
    '[.items[] | select(.scope.name == $name) | .results[]? | select(.result == $want)] | length'
}

echo "--- check 1: a ClusterPolicy exists ---"
if ! kubectl get clusterpolicy -o name 2>/dev/null | grep -q .; then
  echo "FAIL: no ClusterPolicy found on the cluster."
  exit 1
fi
echo "OK: at least one ClusterPolicy exists."

echo "--- check 2: the three legacy Pods (created before the policy) are still running ---"
for pod in legacy-svc-compliant legacy-svc-noncompliant legacy-svc-latest-tag; do
  phase=$(kubectl get pod "$pod" -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)
  if [ "$phase" != "Running" ]; then
    echo "FAIL: legacy Pod '$pod' is not Running (phase='$phase')."
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
  echo "FAIL: a fresh non-compliant Pod was rejected. This lab requires Audit mode."
  cat /tmp/err-audit
  FAIL=1
fi
kubectl delete ns "$CHECK_NS" --ignore-not-found >/dev/null 2>&1

echo "--- check 4: background scan reaches back for the team-label rule ---"
echo "Polling PolicyReport entries in namespace '${NS}'..."

FOUND_NONCOMPLIANT_FAIL=0
FOUND_COMPLIANT_PASS=0
FOUND_LATEST_TEAM_PASS=0
FOUND_LATEST_SKIP=0

for i in $(seq 1 30); do
  if [ "$FOUND_NONCOMPLIANT_FAIL" -eq 0 ] && report_has_result "$NS" "legacy-svc-noncompliant" "fail"; then
    FOUND_NONCOMPLIANT_FAIL=1
  fi
  if [ "$FOUND_COMPLIANT_PASS" -eq 0 ] && report_has_result "$NS" "legacy-svc-compliant" "pass"; then
    FOUND_COMPLIANT_PASS=1
  fi
  if [ "$FOUND_LATEST_TEAM_PASS" -eq 0 ] && report_has_result "$NS" "legacy-svc-latest-tag" "pass"; then
    FOUND_LATEST_TEAM_PASS=1
  fi
  if [ "$FOUND_LATEST_SKIP" -eq 0 ] && report_has_result "$NS" "legacy-svc-latest-tag" "skip"; then
    FOUND_LATEST_SKIP=1
  fi

  if [ "$FOUND_NONCOMPLIANT_FAIL" -eq 1 ] && [ "$FOUND_COMPLIANT_PASS" -eq 1 ] \
     && [ "$FOUND_LATEST_TEAM_PASS" -eq 1 ] && [ "$FOUND_LATEST_SKIP" -eq 1 ]; then
    break
  fi
  sleep 5
done

if [ "$FOUND_NONCOMPLIANT_FAIL" -eq 1 ]; then
  echo "OK: 'legacy-svc-noncompliant' (no team label) has a 'fail' result -- the team-label rule reached it."
else
  echo "FAIL: no 'fail' result found for 'legacy-svc-noncompliant'."
  FAIL=1
fi

if [ "$FOUND_COMPLIANT_PASS" -eq 1 ]; then
  echo "OK: 'legacy-svc-compliant' has a 'pass' result."
else
  echo "FAIL: no 'pass' result found for 'legacy-svc-compliant'."
  FAIL=1
fi

if [ "$FOUND_LATEST_TEAM_PASS" -eq 1 ]; then
  echo "OK: 'legacy-svc-latest-tag' passes the team-label rule (it does carry a team label)."
else
  echo "FAIL: no 'pass' result found for 'legacy-svc-latest-tag' -- the team-label rule should still pass it."
  FAIL=1
fi

echo "--- check 5: the request.operation-gated rule never produces a real 'fail' during a background scan ---"
FAIL_COUNT=$(report_result_count "$NS" "legacy-svc-latest-tag" "fail")
if [ "$FAIL_COUNT" = "0" ]; then
  echo "OK: 'legacy-svc-latest-tag' has zero 'fail' results, even though it runs the ':latest' image."
else
  echo "FAIL: 'legacy-svc-latest-tag' has $FAIL_COUNT 'fail' result(s). Your image-tag rule must be gated so it only"
  echo "      applies on a real admission request (e.g. a precondition on request.operation), or it will wrongly"
  echo "      flag this Pod during the background scan instead of skipping it."
  FAIL=1
fi

if [ "$FOUND_LATEST_SKIP" -eq 1 ]; then
  echo "OK: 'legacy-svc-latest-tag' has a 'skip' result -- proof the request-context-gated rule was evaluated by the"
  echo "    scan and short-circuited on its precondition, instead of silently not existing at all."
else
  echo "FAIL: no 'skip' result found for 'legacy-svc-latest-tag'. Did you write a second rule gated on request-only"
  echo "      context (such as a precondition on request.operation)? Without it, there is nothing to prove."
  FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
exit 0
