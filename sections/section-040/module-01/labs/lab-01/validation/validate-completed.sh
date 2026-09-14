#!/usr/bin/env bash
set -uo pipefail

NS="mutate-check"
FAIL=0

kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create ns "$NS" >/dev/null 2>&1

if ! kubectl get clusterpolicy -o name 2>/dev/null | grep -q .; then
  echo "FAIL: no ClusterPolicy found on the cluster."
  exit 1
fi

echo "--- check 1: a plain Pod (no labels, no imagePullPolicy) gets both fields injected ---"
cat <<EOF | kubectl apply -f - >/tmp/out1 2>/tmp/err1
apiVersion: v1
kind: Pod
metadata:
  name: plain-pod
  namespace: $NS
spec:
  containers:
    - name: app
      image: nginx
EOF
if [ $? -ne 0 ]; then
  echo "FAIL: plain-pod was rejected; a mutate rule should never block admission on its own."
  cat /tmp/err1
  FAIL=1
else
  kubectl wait --for=jsonpath='{.status.phase}'=Running pod/plain-pod -n "$NS" --timeout=60s >/dev/null 2>&1 || true
  label=$(kubectl get pod plain-pod -n "$NS" -o jsonpath='{.metadata.labels.managed-by}' 2>/dev/null)
  pullpolicy=$(kubectl get pod plain-pod -n "$NS" -o jsonpath='{.spec.containers[0].imagePullPolicy}' 2>/dev/null)
  if [ "$label" = "platform" ]; then
    echo "OK: plain-pod carries label managed-by=platform."
  else
    echo "FAIL: plain-pod's persisted managed-by label is '$label', expected 'platform'."
    FAIL=1
  fi
  if [ "$pullpolicy" = "IfNotPresent" ]; then
    echo "OK: plain-pod's container has imagePullPolicy=IfNotPresent."
  else
    echo "FAIL: plain-pod's persisted imagePullPolicy is '$pullpolicy', expected 'IfNotPresent'."
    FAIL=1
  fi
fi

echo "--- check 2: a two-container Pod gets the default on EVERY container, not just the first ---"
cat <<EOF | kubectl apply -f - >/tmp/out2 2>/tmp/err2
apiVersion: v1
kind: Pod
metadata:
  name: multi-container-pod
  namespace: $NS
spec:
  containers:
    - name: app
      image: nginx
    - name: sidecar
      image: busybox
      command: ["sleep", "3600"]
EOF
if [ $? -ne 0 ]; then
  echo "FAIL: multi-container-pod was rejected."
  cat /tmp/err2
  FAIL=1
else
  kubectl wait --for=jsonpath='{.status.phase}'=Running pod/multi-container-pod -n "$NS" --timeout=60s >/dev/null 2>&1 || true
  app_policy=$(kubectl get pod multi-container-pod -n "$NS" -o jsonpath='{.spec.containers[0].imagePullPolicy}' 2>/dev/null)
  sidecar_policy=$(kubectl get pod multi-container-pod -n "$NS" -o jsonpath='{.spec.containers[1].imagePullPolicy}' 2>/dev/null)
  if [ "$app_policy" = "IfNotPresent" ] && [ "$sidecar_policy" = "IfNotPresent" ]; then
    echo "OK: both containers ('app' and 'sidecar') have imagePullPolicy=IfNotPresent."
  else
    echo "FAIL: expected both containers at IfNotPresent, got app='$app_policy' sidecar='$sidecar_policy'. A plain patchStrategicMerge list entry only reaches container index 0 -- did you use the (name) anchor?"
    FAIL=1
  fi
fi

echo "--- check 3: a Pod that already sets CONFLICTING values must have them overridden by the policy ---"
cat <<EOF | kubectl apply -f - >/tmp/out3 2>/tmp/err3
apiVersion: v1
kind: Pod
metadata:
  name: conflict-pod
  namespace: $NS
  labels:
    managed-by: team-x
spec:
  containers:
    - name: app
      image: nginx
      imagePullPolicy: Always
EOF
if [ $? -ne 0 ]; then
  echo "FAIL: conflict-pod was rejected; a mutate rule should never block admission on its own."
  cat /tmp/err3
  FAIL=1
else
  kubectl wait --for=jsonpath='{.status.phase}'=Running pod/conflict-pod -n "$NS" --timeout=60s >/dev/null 2>&1 || true
  label=$(kubectl get pod conflict-pod -n "$NS" -o jsonpath='{.metadata.labels.managed-by}' 2>/dev/null)
  pullpolicy=$(kubectl get pod conflict-pod -n "$NS" -o jsonpath='{.spec.containers[0].imagePullPolicy}' 2>/dev/null)
  if [ "$label" = "platform" ]; then
    echo "OK: conflicting label 'team-x' was overridden to 'platform'."
  else
    echo "FAIL: conflict-pod's managed-by label is '$label', expected the policy to override it to 'platform'."
    FAIL=1
  fi
  if [ "$pullpolicy" = "IfNotPresent" ]; then
    echo "OK: conflicting imagePullPolicy 'Always' was overridden to 'IfNotPresent'."
  else
    echo "FAIL: conflict-pod's imagePullPolicy is '$pullpolicy', expected the policy to override it to 'IfNotPresent'."
    FAIL=1
  fi
fi

kubectl delete ns "$NS" --ignore-not-found >/dev/null 2>&1

if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
exit 0
