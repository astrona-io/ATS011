#!/usr/bin/env bash
set -uo pipefail

NS="verifyimage-capstone-check"
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

echo "--- check 1: unsigned image, no limits -> REJECT ---"
cat <<EOF > /tmp/p1.yaml
apiVersion: v1
kind: Pod
metadata:
  name: bad-unsigned-no-limits
  namespace: $NS
spec:
  containers:
    - name: app
      image: ghcr.io/kyverno/test-verify-image:unsigned
EOF
reject_case "unsigned image with no limits" /tmp/p1.yaml

echo "--- check 2: signed image, missing limits -> REJECT (validate rule) ---"
cat <<EOF > /tmp/p2.yaml
apiVersion: v1
kind: Pod
metadata:
  name: bad-signed-no-limits
  namespace: $NS
spec:
  containers:
    - name: app
      image: ghcr.io/kyverno/test-verify-image:signed
EOF
reject_case "signed image missing resource limits" /tmp/p2.yaml

echo "--- check 3: unsigned image, WITH limits -> REJECT (verifyImages rule) ---"
cat <<EOF > /tmp/p3.yaml
apiVersion: v1
kind: Pod
metadata:
  name: bad-unsigned-with-limits
  namespace: $NS
spec:
  containers:
    - name: app
      image: ghcr.io/kyverno/test-verify-image:unsigned
      resources:
        limits: { cpu: "100m", memory: "64Mi" }
EOF
reject_case "unsigned image despite having resource limits" /tmp/p3.yaml

echo "--- check 4: signed image, WITH limits, two containers -> ADMIT ---"
cat <<EOF > /tmp/p4.yaml
apiVersion: v1
kind: Pod
metadata:
  name: good-signed-and-limited
  namespace: $NS
spec:
  containers:
    - name: app
      image: ghcr.io/kyverno/test-verify-image:signed
      resources:
        limits: { cpu: "100m", memory: "64Mi" }
    - name: sidecar
      image: ghcr.io/kyverno/test-verify-image:signed
      command: ["sleep", "3600"]
      resources:
        limits: { cpu: "50m", memory: "32Mi" }
EOF
admit_case "fully compliant two-container Pod (signed + limited)" /tmp/p4.yaml

kubectl delete ns "$NS" --ignore-not-found >/dev/null 2>&1

if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
exit 0
