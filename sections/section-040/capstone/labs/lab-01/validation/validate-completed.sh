#!/usr/bin/env bash
set -uo pipefail

LEGACY_NS="legacy-workloads"
CHECK_NS="mutate-capstone-check"
FAIL=0

if ! kubectl get clusterpolicy -o name 2>/dev/null | grep -q .; then
  echo "FAIL: no ClusterPolicy found on the cluster."
  exit 1
fi

echo "--- check 1: the two legacy Pods (created before the policy) are still running ---"
for pod in legacy-pod-a legacy-pod-b; do
  phase=$(kubectl get pod "$pod" -n "$LEGACY_NS" -o jsonpath='{.status.phase}' 2>/dev/null)
  if [ "$phase" != "Running" ]; then
    echo "FAIL: legacy Pod '$pod' is not Running (phase='$phase')."
    FAIL=1
  else
    echo "OK: '$pod' is still Running."
  fi
done

echo "--- check 2: both legacy Pods get retroactively patched to managed-by=platform ---"
echo "Polling (this happens via mutateExistingOnPolicyUpdate, not instantly)..."

FOUND_A=0
FOUND_B=0
for i in $(seq 1 30); do
  label_a=$(kubectl get pod legacy-pod-a -n "$LEGACY_NS" -o jsonpath='{.metadata.labels.managed-by}' 2>/dev/null)
  label_b=$(kubectl get pod legacy-pod-b -n "$LEGACY_NS" -o jsonpath='{.metadata.labels.managed-by}' 2>/dev/null)
  [ "$label_a" = "platform" ] && FOUND_A=1
  [ "$label_b" = "platform" ] && FOUND_B=1
  if [ "$FOUND_A" -eq 1 ] && [ "$FOUND_B" -eq 1 ]; then
    break
  fi
  sleep 3
done

if [ "$FOUND_A" -eq 1 ]; then
  echo "OK: legacy-pod-a (had no managed-by label) was backfilled to managed-by=platform."
else
  echo "FAIL: legacy-pod-a never got managed-by=platform. Did you set mutateExistingOnPolicyUpdate: true with a targets block pointing at Pods in '$LEGACY_NS'?"
  FAIL=1
fi

if [ "$FOUND_B" -eq 1 ]; then
  echo "OK: legacy-pod-b (had managed-by=legacy-team) was overridden to managed-by=platform."
else
  echo "FAIL: legacy-pod-b never got its conflicting managed-by label overridden to 'platform'."
  FAIL=1
fi

echo "--- check 3: a brand-new Pod created AFTER the policy exists still gets both admission-time defaults ---"
kubectl get ns "$CHECK_NS" >/dev/null 2>&1 || kubectl create ns "$CHECK_NS" >/dev/null 2>&1
cat <<EOF | kubectl apply -f - >/tmp/out-fresh 2>/tmp/err-fresh
apiVersion: v1
kind: Pod
metadata:
  name: fresh-pod
  namespace: $CHECK_NS
spec:
  containers:
    - name: app
      image: nginx
EOF
if [ $? -ne 0 ]; then
  echo "FAIL: fresh-pod was rejected; a mutate rule should never block admission on its own."
  cat /tmp/err-fresh
  FAIL=1
else
  kubectl wait --for=jsonpath='{.status.phase}'=Running pod/fresh-pod -n "$CHECK_NS" --timeout=60s >/dev/null 2>&1 || true
  label=$(kubectl get pod fresh-pod -n "$CHECK_NS" -o jsonpath='{.metadata.labels.managed-by}' 2>/dev/null)
  pullpolicy=$(kubectl get pod fresh-pod -n "$CHECK_NS" -o jsonpath='{.spec.containers[0].imagePullPolicy}' 2>/dev/null)
  if [ "$label" = "platform" ]; then
    echo "OK: fresh-pod carries label managed-by=platform (admission-time path)."
  else
    echo "FAIL: fresh-pod's managed-by label is '$label', expected 'platform'."
    FAIL=1
  fi
  if [ "$pullpolicy" = "IfNotPresent" ]; then
    echo "OK: fresh-pod's container has imagePullPolicy=IfNotPresent (admission-time path)."
  else
    echo "FAIL: fresh-pod's imagePullPolicy is '$pullpolicy', expected 'IfNotPresent'."
    FAIL=1
  fi
fi

kubectl delete ns "$CHECK_NS" --ignore-not-found >/dev/null 2>&1

if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
exit 0
