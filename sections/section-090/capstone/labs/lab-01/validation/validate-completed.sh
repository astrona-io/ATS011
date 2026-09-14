#!/usr/bin/env bash
set -uo pipefail

NS="autogen-capstone-check"
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

echo "--- check 1: bare non-compliant Pod -> REJECT (original rule always governs Pods directly) ---"
cat <<EOF > /tmp/p1.yaml
apiVersion: v1
kind: Pod
metadata:
  name: bad-pod
  namespace: $NS
spec:
  containers:
    - name: app
      image: nginx
EOF
reject_case "bare Pod with no team label" /tmp/p1.yaml

echo "--- check 2: non-compliant Deployment -> REJECT (Deployment is in autogen scope) ---"
cat <<EOF > /tmp/p2.yaml
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
reject_case "Deployment with no team label" /tmp/p2.yaml

echo "--- check 3: compliant Deployment -> ADMIT ---"
cat <<EOF > /tmp/p3.yaml
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
admit_case "compliant Deployment" /tmp/p3.yaml

echo "--- check 4: non-compliant Job -> the Job object itself must be ADMITTED (Job excluded from autogen scope) ---"
cat <<EOF > /tmp/p4.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: bad-job
  namespace: $NS
spec:
  template:
    spec:
      containers:
        - name: app
          image: nginx
          command: ["/bin/true"]
      restartPolicy: Never
EOF
if kubectl apply -f /tmp/p4.yaml 2>/tmp/err4; then
  echo "OK: non-compliant Job admitted at the Job level (autogen correctly excluded Job)."
else
  echo "FAIL: the Job object itself was rejected — autogen-controllers must exclude Job."
  cat /tmp/err4
  FAIL=1
fi
kubectl delete -f /tmp/p4.yaml --ignore-not-found >/dev/null 2>&1

echo "--- check 5: non-compliant CronJob -> the CronJob object itself must be ADMITTED (CronJob excluded from autogen scope) ---"
cat <<EOF > /tmp/p5.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: bad-cronjob
  namespace: $NS
spec:
  schedule: "*/5 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: app
              image: nginx
          restartPolicy: Never
EOF
if kubectl apply -f /tmp/p5.yaml 2>/tmp/err5; then
  echo "OK: non-compliant CronJob admitted at the CronJob level (autogen correctly excluded CronJob)."
else
  echo "FAIL: the CronJob object itself was rejected — autogen-controllers must exclude CronJob."
  cat /tmp/err5
  FAIL=1
fi
kubectl delete -f /tmp/p5.yaml --ignore-not-found >/dev/null 2>&1

kubectl delete ns "$NS" --ignore-not-found >/dev/null 2>&1

if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
exit 0
