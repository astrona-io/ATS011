#!/usr/bin/env bash
set -uo pipefail

NS="autogen-check"
FAIL=0

kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create ns "$NS" >/dev/null 2>&1

if ! kubectl get clusterpolicy -o name 2>/dev/null | grep -q .; then
  echo "FAIL: no ClusterPolicy found on the cluster."
  exit 1
fi

echo "--- check 1: bare Pod with no team label must be REJECTED ---"
if kubectl run bad-pod -n "$NS" --image=nginx --restart=Never 2>/tmp/err1; then
  echo "FAIL: a Pod with no team label was admitted."
  kubectl delete pod bad-pod -n "$NS" --ignore-not-found >/dev/null 2>&1
  FAIL=1
else
  grep -qi "denied the request\|admission webhook" /tmp/err1 && echo "OK: rejected as expected." || { echo "FAIL: rejected, but not by an admission webhook."; cat /tmp/err1; FAIL=1; }
fi

echo "--- check 2: non-compliant Deployment must ALSO be REJECTED (proves autogen expanded the rule) ---"
cat <<EOF > /tmp/bad-deploy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bad-deploy
  namespace: $NS
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bad-deploy
  template:
    metadata:
      labels:
        app: bad-deploy
    spec:
      containers:
        - name: app
          image: nginx
EOF
if kubectl apply -f /tmp/bad-deploy.yaml 2>/tmp/err2; then
  echo "FAIL: a Deployment whose Pod template has no team label was admitted (autogen did not extend the rule to Deployment)."
  kubectl delete -f /tmp/bad-deploy.yaml --ignore-not-found >/dev/null 2>&1
  FAIL=1
else
  grep -qi "denied the request\|admission webhook" /tmp/err2 && echo "OK: rejected as expected." || { echo "FAIL: rejected, but not by an admission webhook."; cat /tmp/err2; FAIL=1; }
fi

echo "--- check 3: fully compliant Deployment must be ADMITTED ---"
cat <<EOF > /tmp/good-deploy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: good-deploy
  namespace: $NS
spec:
  replicas: 1
  selector:
    matchLabels:
      app: good-deploy
  template:
    metadata:
      labels:
        app: good-deploy
        team: platform
    spec:
      containers:
        - name: app
          image: nginx
EOF
if kubectl apply -f /tmp/good-deploy.yaml 2>/tmp/err3; then
  echo "OK: admitted as expected."
  kubectl delete -f /tmp/good-deploy.yaml --ignore-not-found >/dev/null 2>&1
else
  echo "FAIL: a fully compliant Deployment (team label on the Pod template) was rejected."
  cat /tmp/err3
  FAIL=1
fi

kubectl delete pod bad-pod -n "$NS" --ignore-not-found >/dev/null 2>&1
kubectl delete ns "$NS" --ignore-not-found >/dev/null 2>&1

if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
exit 0
