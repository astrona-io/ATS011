#!/usr/bin/env bash
set -uo pipefail

NS="json-patch-check"
FAIL=0

kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create ns "$NS" >/dev/null 2>&1

if ! kubectl get clusterpolicy -o name 2>/dev/null | grep -q .; then
  echo "FAIL: no ClusterPolicy found on the cluster."
  exit 1
fi

echo "--- check 1: Pod whose first container already has an env array ---"
cat <<EOF | kubectl apply -f - 2>/tmp/err1
apiVersion: v1
kind: Pod
metadata:
  name: has-env
  namespace: $NS
spec:
  containers:
    - name: app
      image: nginx
      env:
        - name: EXISTING
          value: "one"
EOF
if [ $? -ne 0 ]; then
  echo "FAIL: has-env Pod was rejected."
  cat /tmp/err1
  FAIL=1
else
  kubectl wait --for=jsonpath='{.status.phase}'=Running pod/has-env -n "$NS" --timeout=60s >/dev/null 2>&1
  EXISTING_VAL=$(kubectl get pod has-env -n "$NS" -o jsonpath='{.spec.containers[0].env[?(@.name=="EXISTING")].value}' 2>/dev/null)
  INJECTED_VAL=$(kubectl get pod has-env -n "$NS" -o jsonpath='{.spec.containers[0].env[?(@.name=="INJECTED_BY_POLICY")].value}' 2>/dev/null)
  if [ "$EXISTING_VAL" != "one" ]; then
    echo "FAIL: pre-existing env entry 'EXISTING' was lost or altered (got '$EXISTING_VAL')."
    FAIL=1
  elif [ "$INJECTED_VAL" != "true" ]; then
    echo "FAIL: INJECTED_BY_POLICY env var was not appended (got '$INJECTED_VAL')."
    FAIL=1
  else
    echo "OK: existing env entry preserved and INJECTED_BY_POLICY appended."
  fi
fi

echo "--- check 2: Pod whose first container has no env array at all ---"
cat <<EOF | kubectl apply -f - 2>/tmp/err2
apiVersion: v1
kind: Pod
metadata:
  name: no-env
  namespace: $NS
spec:
  containers:
    - name: app
      image: nginx
EOF
if [ $? -ne 0 ]; then
  echo "FAIL: no-env Pod was rejected."
  cat /tmp/err2
  FAIL=1
else
  kubectl wait --for=jsonpath='{.status.phase}'=Running pod/no-env -n "$NS" --timeout=60s >/dev/null 2>&1
  INJECTED_VAL=$(kubectl get pod no-env -n "$NS" -o jsonpath='{.spec.containers[0].env[?(@.name=="INJECTED_BY_POLICY")].value}' 2>/dev/null)
  ENV_COUNT=$(kubectl get pod no-env -n "$NS" -o jsonpath='{.spec.containers[0].env}' 2>/dev/null | grep -o '"name"' | wc -l | tr -d ' ')
  if [ "$INJECTED_VAL" != "true" ]; then
    echo "FAIL: INJECTED_BY_POLICY env var was not created on a container with no prior env array (got '$INJECTED_VAL')."
    FAIL=1
  elif [ "$ENV_COUNT" != "1" ]; then
    echo "FAIL: expected exactly one env entry on no-env, found $ENV_COUNT."
    FAIL=1
  else
    echo "OK: env array created from scratch with exactly the injected entry."
  fi
fi

kubectl delete ns "$NS" --ignore-not-found >/dev/null 2>&1

if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
exit 0
