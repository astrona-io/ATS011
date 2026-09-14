#!/usr/bin/env bash
set -uo pipefail

SWEEP_NS="capstone-cleanup"
KEEP_NS="capstone-keep"
FAIL=0
WAIT_SECONDS=180

echo "--- check 0: a ClusterCleanupPolicy must exist ---"
if ! kubectl get clustercleanuppolicy -o name 2>/dev/null | grep -q .; then
  echo "FAIL: no ClusterCleanupPolicy found on the cluster."
  exit 1
fi
echo "OK: ClusterCleanupPolicy present."

echo "--- check 1: the cleanup controller must hold delete permission on ConfigMaps ---"
if kubectl auth can-i delete configmaps \
     --as=system:serviceaccount:kyverno:kyverno-cleanup-controller >/dev/null 2>&1; then
  echo "OK: kyverno-cleanup-controller can delete configmaps."
else
  echo "FAIL: the kyverno-cleanup-controller ServiceAccount cannot delete configmaps."
  echo "      Create a ClusterRole labelled rbac.kyverno.io/aggregate-to-cleanup-controller=true"
  echo "      granting get/list/watch/delete on resources: [\"configmaps\"]."
  FAIL=1
fi

kubectl get ns "$SWEEP_NS" >/dev/null 2>&1 || kubectl create ns "$SWEEP_NS" >/dev/null 2>&1
kubectl get ns "$KEEP_NS"  >/dev/null 2>&1 || kubectl create ns "$KEEP_NS"  >/dev/null 2>&1
kubectl delete cm cm-sweep cm-retained cm-unlabelled -n "$SWEEP_NS" --ignore-not-found >/dev/null 2>&1
kubectl delete cm cm-other-ns -n "$KEEP_NS" --ignore-not-found >/dev/null 2>&1

echo "--- check 2: seeding four ConfigMaps (one must go, three must survive) ---"
kubectl apply -f - >/dev/null 2>&1 <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: cm-sweep
  namespace: $SWEEP_NS
  labels:
    lifecycle: ephemeral
data:
  note: "labelled, not retained, in the sweep namespace -- must be deleted"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: cm-retained
  namespace: $SWEEP_NS
  labels:
    lifecycle: ephemeral
  annotations:
    example.com/retain: "true"
data:
  note: "labelled but retained -- must survive"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: cm-unlabelled
  namespace: $SWEEP_NS
data:
  note: "no lifecycle label -- must survive"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: cm-other-ns
  namespace: $KEEP_NS
  labels:
    lifecycle: ephemeral
data:
  note: "labelled but in the wrong namespace -- must survive"
EOF
for pair in "$SWEEP_NS/cm-sweep" "$SWEEP_NS/cm-retained" "$SWEEP_NS/cm-unlabelled" "$KEEP_NS/cm-other-ns"; do
  ns="${pair%%/*}"; name="${pair##*/}"
  if ! kubectl get cm "$name" -n "$ns" >/dev/null 2>&1; then
    echo "FAIL: could not create test ConfigMap $ns/$name."
    exit 1
  fi
done
echo "OK: cm-sweep, cm-retained, cm-unlabelled ($SWEEP_NS) and cm-other-ns ($KEEP_NS) created."

echo "--- check 3: waiting up to ${WAIT_SECONDS}s for a sweep to delete cm-sweep ---"
SWEPT=0
for i in $(seq 1 $((WAIT_SECONDS / 10))); do
  sleep 10
  if ! kubectl get cm cm-sweep -n "$SWEEP_NS" >/dev/null 2>&1; then
    SWEPT=1
    echo "OK: cm-sweep was deleted after ~$((i * 10))s."
    break
  fi
done
if [ "$SWEPT" -ne 1 ]; then
  echo "FAIL: cm-sweep still exists after ${WAIT_SECONDS}s."
  echo "      Check the match block selects ConfigMaps with label lifecycle=ephemeral in"
  echo "      namespace $SWEEP_NS, and that the schedule is \"* * * * *\"."
  kubectl get clustercleanuppolicy -o jsonpath='{range .items[*]}{.metadata.name}{" schedule="}{.spec.schedule}{" lastExecution="}{.status.lastExecutionTime}{"\n"}{end}' 2>/dev/null
  FAIL=1
fi

echo "--- check 4: the three survivors must all still exist ---"
if kubectl get cm cm-retained -n "$SWEEP_NS" >/dev/null 2>&1; then
  echo "OK: cm-retained survived (the example.com/retain annotation exempted it)."
else
  echo "FAIL: cm-retained was deleted -- the retain-annotation exemption is missing or wrong."
  echo "      An annotation cannot be filtered in match; it needs a conditions entry over the"
  echo "      target variable, e.g. {{ target.metadata.annotations.\"example.com/retain\" || '' }}."
  FAIL=1
fi
if kubectl get cm cm-unlabelled -n "$SWEEP_NS" >/dev/null 2>&1; then
  echo "OK: cm-unlabelled survived."
else
  echo "FAIL: cm-unlabelled was deleted -- the policy is not filtering on the lifecycle label."
  FAIL=1
fi
if kubectl get cm cm-other-ns -n "$KEEP_NS" >/dev/null 2>&1; then
  echo "OK: cm-other-ns survived."
else
  echo "FAIL: cm-other-ns was deleted -- the policy is not restricted to the $SWEEP_NS namespace."
  FAIL=1
fi

kubectl delete cm cm-sweep cm-retained cm-unlabelled -n "$SWEEP_NS" --ignore-not-found >/dev/null 2>&1
kubectl delete cm cm-other-ns -n "$KEEP_NS" --ignore-not-found >/dev/null 2>&1

if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
exit 0
