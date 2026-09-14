#!/usr/bin/env bash
set -uo pipefail

NS="policy-capstone-check"
FAIL=0

kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create ns "$NS" >/dev/null 2>&1

if ! kubectl get clusterpolicy -o name 2>/dev/null | grep -q .; then
  echo "FAIL: no ClusterPolicy found on the cluster."
  exit 1
fi

reject_case () {
  local name="$1" file="$2"
  if kubectl apply -f "$file" 2>/tmp/err; then
    echo "FAIL: $name was admitted but should have been rejected."
    kubectl delete -f "$file" --ignore-not-found >/dev/null 2>&1
    FAIL=1
  else
    grep -qi "denied the request\|admission webhook" /tmp/err && echo "OK: $name rejected." || { echo "FAIL: $name rejected but not by a webhook."; cat /tmp/err; FAIL=1; }
  fi
}

admit_case () {
  local name="$1" file="$2"
  if kubectl apply -f "$file" 2>/tmp/err; then
    echo "OK: $name admitted."
    kubectl delete -f "$file" --ignore-not-found >/dev/null 2>&1
  else
    echo "FAIL: $name was rejected but should have been admitted."
    cat /tmp/err
    FAIL=1
  fi
}

echo "--- check 1: bare Pod, no ownership signal, no limits, latest tag -> REJECT ---"
cat <<EOF > /tmp/p1.yaml
apiVersion: v1
kind: Pod
metadata:
  name: bad-bare
  namespace: $NS
spec:
  containers:
    - name: app
      image: nginx:latest
EOF
reject_case "bare Pod" /tmp/p1.yaml

echo "--- check 2: owner annotation only, compliant containers -> ADMIT (anyPattern OR path) ---"
cat <<EOF > /tmp/p2.yaml
apiVersion: v1
kind: Pod
metadata:
  name: good-via-annotation
  namespace: $NS
  annotations:
    owner: "platform-team"
spec:
  containers:
    - name: app
      image: nginx:1.25
      resources:
        limits: { cpu: "250m", memory: "128Mi" }
EOF
admit_case "owner-annotated Pod" /tmp/p2.yaml

echo "--- check 3: team label present, second container uses :latest -> REJECT ---"
cat <<EOF > /tmp/p3.yaml
apiVersion: v1
kind: Pod
metadata:
  name: bad-latest-tag
  namespace: $NS
  labels:
    team: platform
spec:
  containers:
    - name: app
      image: nginx:1.25
      resources:
        limits: { cpu: "250m", memory: "128Mi" }
    - name: sidecar
      image: busybox:latest
      command: ["sleep", "3600"]
      resources:
        limits: { cpu: "100m", memory: "64Mi" }
EOF
reject_case "Pod with a :latest sidecar" /tmp/p3.yaml

echo "--- check 4: team label present, second container missing limits -> REJECT ---"
cat <<EOF > /tmp/p4.yaml
apiVersion: v1
kind: Pod
metadata:
  name: bad-missing-limits
  namespace: $NS
  labels:
    team: platform
spec:
  containers:
    - name: app
      image: nginx:1.25
      resources:
        limits: { cpu: "250m", memory: "128Mi" }
    - name: sidecar
      image: busybox:1.36
      command: ["sleep", "3600"]
EOF
reject_case "Pod with a sidecar missing limits" /tmp/p4.yaml

echo "--- check 5: fully compliant two-container Pod -> ADMIT ---"
cat <<EOF > /tmp/p5.yaml
apiVersion: v1
kind: Pod
metadata:
  name: good-full
  namespace: $NS
  labels:
    team: platform
spec:
  containers:
    - name: app
      image: nginx:1.25
      resources:
        limits: { cpu: "250m", memory: "128Mi" }
    - name: sidecar
      image: busybox:1.36
      command: ["sleep", "3600"]
      resources:
        limits: { cpu: "100m", memory: "64Mi" }
EOF
admit_case "fully compliant Pod" /tmp/p5.yaml

kubectl delete ns "$NS" --ignore-not-found >/dev/null 2>&1

if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
exit 0
