#!/usr/bin/env bash
set -uo pipefail

# A unique namespace per run: a broken policy can block Pod deletion (a CEL expression
# that assumes object exists errors on DELETE too), so no run may depend on cleaning up
# after a previous one.
NS="jsonpatch-capstone-check-$(date +%s)"
FAIL=0

if ! kubectl get clusterpolicy -o name 2>/dev/null | grep -q .; then
  echo "FAIL: no ClusterPolicy found on the cluster."
  exit 1
fi

echo "--- check 0: the policies must use patchesJson6902, not patchStrategicMerge ---"
ALL_POLICIES="$(kubectl get clusterpolicy -o yaml 2>/dev/null)"
if ! grep -q "patchesJson6902" <<<"$ALL_POLICIES"; then
  echo "FAIL: no ClusterPolicy on the cluster uses mutate.patchesJson6902."
  FAIL=1
else
  echo "OK: patchesJson6902 is in use."
fi
if grep -q "patchStrategicMerge" <<<"$ALL_POLICIES"; then
  echo "FAIL: a ClusterPolicy uses patchStrategicMerge; this capstone requires patchesJson6902 exclusively."
  FAIL=1
else
  echo "OK: no patchStrategicMerge in use."
fi

kubectl create ns "$NS" >/dev/null 2>&1

echo "--- check 1: a Pod carrying the disallowed annotation must be admitted, stripped, and stamped ---"
cat <<EOF > /tmp/cap080-pod-a.yaml
apiVersion: v1
kind: Pod
metadata:
  name: has-disallowed
  namespace: $NS
  annotations:
    legacy/unmanaged-scanner: "true"
    team: platform
spec:
  containers:
    - name: app
      image: nginx
EOF
if ! kubectl apply -f /tmp/cap080-pod-a.yaml 2>/tmp/cap080-err1; then
  echo "FAIL: a Pod carrying legacy/unmanaged-scanner was rejected outright."
  cat /tmp/cap080-err1
  FAIL=1
else
  LEGACY="$(kubectl get pod has-disallowed -n "$NS" -o jsonpath='{.metadata.annotations.legacy/unmanaged-scanner}' 2>/dev/null)"
  if [ -n "$LEGACY" ]; then
    echo "FAIL: legacy/unmanaged-scanner survived on the persisted Pod (value: '${LEGACY}')."
    FAIL=1
  else
    echo "OK: legacy/unmanaged-scanner was removed."
  fi
  REVIEWED="$(kubectl get pod has-disallowed -n "$NS" -o jsonpath='{.metadata.annotations.policy\.example\.com/reviewed}' 2>/dev/null)"
  if [ "$REVIEWED" = "true" ]; then
    echo "OK: policy.example.com/reviewed=true was added."
  else
    echo "FAIL: policy.example.com/reviewed was not set to \"true\" (got: '${REVIEWED}')."
    FAIL=1
  fi
  TEAM="$(kubectl get pod has-disallowed -n "$NS" -o jsonpath='{.metadata.annotations.team}' 2>/dev/null)"
  if [ "$TEAM" = "platform" ]; then
    echo "OK: the unrelated 'team' annotation survived untouched."
  else
    echo "FAIL: an unrelated annotation was lost (team='${TEAM}', expected 'platform')."
    FAIL=1
  fi
fi

echo "--- check 2: a Pod that never had the disallowed annotation must be admitted and stamped ---"
cat <<EOF > /tmp/cap080-pod-b.yaml
apiVersion: v1
kind: Pod
metadata:
  name: no-disallowed
  namespace: $NS
spec:
  containers:
    - name: app
      image: nginx
EOF
if ! kubectl apply -f /tmp/cap080-pod-b.yaml 2>/tmp/cap080-err2; then
  echo "FAIL: a Pod with no annotations at all was rejected -- an unguarded remove/replace is erroring the request."
  cat /tmp/cap080-err2
  FAIL=1
else
  echo "OK: admitted."
  REVIEWED="$(kubectl get pod no-disallowed -n "$NS" -o jsonpath='{.metadata.annotations.policy\.example\.com/reviewed}' 2>/dev/null)"
  if [ "$REVIEWED" = "true" ]; then
    echo "OK: policy.example.com/reviewed=true was added."
  else
    echo "FAIL: policy.example.com/reviewed was not set to \"true\" (got: '${REVIEWED}')."
    FAIL=1
  fi
fi

echo "--- check 3: an existing reviewed annotation with a wrong value must be corrected to \"true\" ---"
cat <<EOF > /tmp/cap080-pod-c.yaml
apiVersion: v1
kind: Pod
metadata:
  name: wrong-reviewed
  namespace: $NS
  annotations:
    policy.example.com/reviewed: "false"
spec:
  containers:
    - name: app
      image: nginx
EOF
if ! kubectl apply -f /tmp/cap080-pod-c.yaml 2>/tmp/cap080-err3; then
  echo "FAIL: a Pod already carrying policy.example.com/reviewed was rejected."
  cat /tmp/cap080-err3
  FAIL=1
else
  REVIEWED="$(kubectl get pod wrong-reviewed -n "$NS" -o jsonpath='{.metadata.annotations.policy\.example\.com/reviewed}' 2>/dev/null)"
  if [ "$REVIEWED" = "true" ]; then
    echo "OK: the pre-existing value was overwritten with \"true\"."
  else
    echo "FAIL: policy.example.com/reviewed is '${REVIEWED}', expected 'true'."
    FAIL=1
  fi
fi

kubectl delete ns "$NS" --ignore-not-found --wait=false >/dev/null 2>&1
rm -f /tmp/cap080-pod-*.yaml /tmp/cap080-err* 2>/dev/null

if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
exit 0
