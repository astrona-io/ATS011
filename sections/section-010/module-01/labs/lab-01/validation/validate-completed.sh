#!/usr/bin/env bash
set -uo pipefail

NS="policy-check"
FAIL=0

kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create ns "$NS" >/dev/null 2>&1

if ! kubectl get clusterpolicy -o name 2>/dev/null | grep -q .; then
  echo "FAIL: no ClusterPolicy found on the cluster."
  exit 1
fi

echo "--- check 1: Pod with no team label, no limits must be REJECTED ---"
if kubectl run bad-no-label -n "$NS" --image=nginx --restart=Never 2>/tmp/err1; then
  echo "FAIL: a Pod with no team label and no resource limits was admitted."
  kubectl delete pod bad-no-label -n "$NS" --ignore-not-found >/dev/null 2>&1
  FAIL=1
else
  grep -qi "denied the request\|admission webhook" /tmp/err1 && echo "OK: rejected as expected." || { echo "FAIL: rejected, but not by an admission webhook."; cat /tmp/err1; FAIL=1; }
fi

echo "--- check 2: labeled Pod, one of two containers missing limits must be REJECTED ---"
cat <<'EOF' | kubectl apply -f - 2>/tmp/err2
apiVersion: v1
kind: Pod
metadata:
  name: bad-partial-limits
  namespace: policy-check
  labels:
    team: platform
spec:
  containers:
    - name: app
      image: nginx
      resources:
        limits: { cpu: "250m", memory: "128Mi" }
    - name: sidecar
      image: busybox
      command: ["sleep", "3600"]
EOF
if [ $? -eq 0 ]; then
  echo "FAIL: a Pod with one container missing resource limits was admitted (foreach not covering every container)."
  kubectl delete pod bad-partial-limits -n "$NS" --ignore-not-found >/dev/null 2>&1
  FAIL=1
else
  grep -qi "denied the request\|admission webhook" /tmp/err2 && echo "OK: rejected as expected." || { echo "FAIL: rejected, but not by an admission webhook."; cat /tmp/err2; FAIL=1; }
fi

echo "--- check 3: fully compliant Pod must be ADMITTED ---"
cat <<'EOF' | kubectl apply -f - 2>/tmp/err3
apiVersion: v1
kind: Pod
metadata:
  name: good-pod
  namespace: policy-check
  labels:
    team: platform
spec:
  containers:
    - name: app
      image: nginx
      resources:
        limits: { cpu: "250m", memory: "128Mi" }
    - name: sidecar
      image: busybox
      command: ["sleep", "3600"]
      resources:
        limits: { cpu: "100m", memory: "64Mi" }
EOF
if [ $? -ne 0 ]; then
  echo "FAIL: a fully compliant Pod (team label + limits on every container) was rejected."
  cat /tmp/err3
  FAIL=1
else
  echo "OK: admitted as expected."
  kubectl delete pod good-pod -n "$NS" --ignore-not-found >/dev/null 2>&1
fi

kubectl delete ns "$NS" --ignore-not-found >/dev/null 2>&1

if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
exit 0
