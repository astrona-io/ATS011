#!/usr/bin/env bash
set -uo pipefail

# A unique namespace per run: a broken policy can block Pod deletion (a CEL expression
# that assumes object exists errors on DELETE too), so no run may depend on cleaning up
# after a previous one.
NS="cleanup-check-$(date +%s)"
FAIL=0
WAIT_SECONDS=180

echo "--- check 0: a ClusterCleanupPolicy must exist ---"
if ! kubectl get clustercleanuppolicy -o name 2>/dev/null | grep -q .; then
  echo "FAIL: no ClusterCleanupPolicy found on the cluster."
  echo "      (A namespaced CleanupPolicy cannot satisfy this task -- the sweep must be cluster-wide.)"
  exit 1
fi
echo "OK: found $(kubectl get clustercleanuppolicy -o name 2>/dev/null | wc -l | tr -d ' ') ClusterCleanupPolicy object(s)."

echo "--- check 1: the cleanup controller must actually hold delete permission on Pods ---"
# Kyverno refuses a cleanup policy at apply time without this, so a policy existing is strong
# evidence -- but check the aggregated ClusterRole directly so the failure message is useful.
if kubectl auth can-i delete pods \
     --as=system:serviceaccount:kyverno:kyverno-cleanup-controller >/dev/null 2>&1; then
  echo "OK: kyverno-cleanup-controller can delete pods."
else
  echo "FAIL: the kyverno-cleanup-controller ServiceAccount cannot delete pods."
  echo "      Create a ClusterRole labelled rbac.kyverno.io/aggregate-to-cleanup-controller=true"
  echo "      granting get/list/watch/delete on resources: [\"pods\"]."
  FAIL=1
fi

# Reuse the namespace across re-submits and force-delete the test Pods by name instead.
# Deleting the namespace would block on Pods still pulling images, and a re-submit issued
# while it is still Terminating cannot create anything in it.
kubectl create ns "$NS" >/dev/null 2>&1

echo "--- check 2: seeding one ephemeral Pod and one that must survive ---"
kubectl run doomed -n "$NS" --image=nginx --restart=Never --labels=lifecycle=ephemeral >/dev/null 2>&1
kubectl run keeper -n "$NS" --image=nginx --restart=Never --labels=lifecycle=permanent >/dev/null 2>&1
if ! kubectl get pod doomed -n "$NS" >/dev/null 2>&1 || ! kubectl get pod keeper -n "$NS" >/dev/null 2>&1; then
  echo "FAIL: could not create the test Pods."
  exit 1
fi
echo "OK: doomed (lifecycle=ephemeral) and keeper (lifecycle=permanent) created."

echo "--- check 3: waiting up to ${WAIT_SECONDS}s for a scheduled sweep to delete 'doomed' ---"
SWEPT=0
for i in $(seq 1 $((WAIT_SECONDS / 10))); do
  sleep 10
  if ! kubectl get pod doomed -n "$NS" >/dev/null 2>&1; then
    SWEPT=1
    echo "OK: 'doomed' was deleted after ~$((i * 10))s."
    break
  fi
done
if [ "$SWEPT" -ne 1 ]; then
  echo "FAIL: 'doomed' (lifecycle=ephemeral) still exists after ${WAIT_SECONDS}s."
  echo "      Check the policy's match block selects Pods with label lifecycle=ephemeral,"
  echo "      and that its schedule is a one-minute cron expression (\"* * * * *\")."
  kubectl get clustercleanuppolicy -o jsonpath='{range .items[*]}{.metadata.name}{" schedule="}{.spec.schedule}{" lastExecution="}{.status.lastExecutionTime}{"\n"}{end}' 2>/dev/null
  FAIL=1
fi

echo "--- check 4: 'keeper' must still be there ---"
if kubectl get pod keeper -n "$NS" >/dev/null 2>&1; then
  echo "OK: 'keeper' (lifecycle=permanent) survived."
else
  echo "FAIL: 'keeper' was deleted too -- the policy is matching Pods it should not."
  echo "      The match block must select on the lifecycle=ephemeral label, not on kind alone."
  FAIL=1
fi

kubectl delete ns "$NS" --ignore-not-found --wait=false >/dev/null 2>&1

if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
exit 0
