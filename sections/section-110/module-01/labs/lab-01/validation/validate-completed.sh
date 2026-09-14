#!/usr/bin/env bash
set -uo pipefail

# A unique namespace per run: a broken policy can block Pod deletion (a CEL expression
# that assumes object exists errors on DELETE too), so no run may depend on cleaning up
# after a previous one.
NS="cel-check-$(date +%s)"
FAIL=0

if ! kubectl get clusterpolicy -o name 2>/dev/null | grep -q .; then
  echo "FAIL: no ClusterPolicy found on the cluster."
  exit 1
fi

ALL_POLICIES="$(kubectl get clusterpolicy -o yaml 2>/dev/null)"

echo "--- check 0: the rule must validate with a CEL expression ---"
if grep -q "expression" <<<"$ALL_POLICIES" && grep -q "cel" <<<"$ALL_POLICIES"; then
  echo "OK: a validate.cel block with expressions is present."
else
  echo "FAIL: no validate.cel expression found on any ClusterPolicy."
  FAIL=1
fi
if grep -qE '^\s+pattern:' <<<"$ALL_POLICIES"; then
  echo "FAIL: a ClusterPolicy uses validate.pattern; this task requires validate.cel."
  FAIL=1
else
  echo "OK: no validate.pattern in use."
fi

echo "--- check 1: the policy must be in Enforce mode ---"
if grep -qE 'validationFailureAction:\s*Enforce|failureAction:\s*Enforce' <<<"$ALL_POLICIES"; then
  echo "OK: Enforce mode set."
else
  echo "FAIL: no policy is in Enforce mode -- violations would only be reported, not blocked."
  FAIL=1
fi

# Reuse the namespace across re-submits and force-delete the test Pods by name instead.
# Deleting the namespace would block on Pods still pulling images, and a re-submit issued
# while it is still Terminating cannot create anything in it.
kubectl create ns "$NS" >/dev/null 2>&1

echo "--- check 2: two containers, only the first limited -> must be REJECTED ---"
cat <<EOF > /tmp/cel111-half.yaml
apiVersion: v1
kind: Pod
metadata:
  name: half-limited
  namespace: $NS
spec:
  containers:
    - name: app
      image: nginx
      resources:
        limits:
          memory: "64Mi"
    - name: sidecar
      image: busybox
      command: ["sleep", "3600"]
EOF
if kubectl apply -f /tmp/cel111-half.yaml 2>/tmp/cel111-err1; then
  echo "FAIL: a Pod whose second container has no memory limit was admitted."
  echo "      An expression that only inspects containers[0] passes a one-container test but fails here."
  kubectl delete -f /tmp/cel111-half.yaml --ignore-not-found --force --grace-period=0 >/dev/null 2>&1
  FAIL=1
else
  if grep -qi "denied the request\|admission webhook\|is invalid" /tmp/cel111-err1; then
    echo "OK: rejected as expected."
  else
    echo "FAIL: rejected, but not by admission control."
    cat /tmp/cel111-err1
    FAIL=1
  fi
fi

echo "--- check 3: no resources block at all -> REJECTED, but not by a CEL evaluation error ---"
cat <<EOF > /tmp/cel111-none.yaml
apiVersion: v1
kind: Pod
metadata:
  name: no-resources
  namespace: $NS
spec:
  containers:
    - name: app
      image: nginx
EOF
if kubectl apply -f /tmp/cel111-none.yaml 2>/tmp/cel111-err2; then
  echo "FAIL: a Pod with no resources block at all was admitted."
  kubectl delete -f /tmp/cel111-none.yaml --ignore-not-found --force --grace-period=0 >/dev/null 2>&1
  FAIL=1
elif grep -qi "resulted in error\|no such key\|no such field" /tmp/cel111-err2; then
  echo "FAIL: the Pod was rejected by a CEL *evaluation error*, not by your rule."
  echo "      Guard optional fields with has() before indexing into them:"
  echo "        has(c.resources) && has(c.resources.limits) && 'memory' in c.resources.limits"
  echo "      Actual message:"
  sed 's/^/        /' /tmp/cel111-err2
  FAIL=1
else
  echo "OK: rejected by the rule, with no CEL evaluation error."
fi

echo "--- check 4: every container limited -> must be ADMITTED ---"
cat <<EOF > /tmp/cel111-full.yaml
apiVersion: v1
kind: Pod
metadata:
  name: fully-limited
  namespace: $NS
spec:
  containers:
    - name: app
      image: nginx
      resources:
        limits:
          memory: "64Mi"
    - name: sidecar
      image: busybox
      command: ["sleep", "3600"]
      resources:
        limits:
          memory: "32Mi"
EOF
if kubectl apply -f /tmp/cel111-full.yaml 2>/tmp/cel111-err3; then
  echo "OK: admitted as expected."
else
  echo "FAIL: a fully compliant Pod was rejected."
  cat /tmp/cel111-err3
  FAIL=1
fi

echo "--- check 5: the compliant Pod must still be DELETABLE ---"
if kubectl delete pod fully-limited -n "$NS" --timeout=60s 2>/tmp/cel111-err4 >/dev/null; then
  echo "OK: deletion works."
else
  echo "FAIL: the compliant Pod could not be deleted."
  echo "      A rule matching Pods with no 'operations' restriction is consulted on DELETE too,"
  echo "      where there is no incoming object -- so the expression errors and denies the request,"
  echo "      making Pods undeletable. has() guards do NOT prevent this; the failure is on 'object'"
  echo "      itself, before your predicate runs. Restrict the match block:"
  echo "        operations: [CREATE, UPDATE]"
  echo "      Actual message:"
  sed 's/^/        /' /tmp/cel111-err4
  FAIL=1
fi

kubectl delete ns "$NS" --ignore-not-found --wait=false >/dev/null 2>&1
rm -f /tmp/cel111-*.yaml /tmp/cel111-err* 2>/dev/null

if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
exit 0
