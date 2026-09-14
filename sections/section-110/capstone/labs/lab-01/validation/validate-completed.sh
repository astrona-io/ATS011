#!/usr/bin/env bash
set -uo pipefail

# A unique namespace per run: a broken policy can block Pod deletion (a CEL expression
# that assumes object exists errors on DELETE too), so no run may depend on cleaning up
# after a previous one.
NS="cel-capstone-check-$(date +%s)"
EXEMPT_NS="cel-exempt"
# Unique per run for the same reason as $NS -- the exempt namespace is fixed by the task,
# so only the Pod name inside it can vary.
EXEMPT_POD="exempt-pod-${NS##*-}"
FAIL=0

echo "--- check 0: a ValidatingPolicy must exist and be ready ---"
VP_NAME="$(kubectl get validatingpolicy -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
if [ -z "$VP_NAME" ]; then
  echo "FAIL: no ValidatingPolicy (policies.kyverno.io) found on the cluster."
  echo "      This capstone requires a ValidatingPolicy, not a ClusterPolicy."
  exit 1
fi
echo "OK: found ValidatingPolicy/$VP_NAME."

VP_YAML="$(kubectl get validatingpolicy "$VP_NAME" -o yaml 2>/dev/null)"

echo "--- check 1: matchConstraints must cover pods on CREATE and UPDATE ---"
OPS="$(kubectl get validatingpolicy "$VP_NAME" -o jsonpath='{.spec.matchConstraints.resourceRules[*].operations[*]}' 2>/dev/null)"
RES="$(kubectl get validatingpolicy "$VP_NAME" -o jsonpath='{.spec.matchConstraints.resourceRules[*].resources[*]}' 2>/dev/null)"
if grep -q "pods" <<<"$RES"; then
  echo "OK: matchConstraints targets pods."
else
  echo "FAIL: matchConstraints does not target 'pods' (got: '${RES}')."
  echo "      resources takes the lowercase plural API resource name, not the Kind."
  FAIL=1
fi
if grep -q "CREATE" <<<"$OPS" && grep -q "UPDATE" <<<"$OPS"; then
  echo "OK: both CREATE and UPDATE are covered."
else
  echo "FAIL: operations must include both CREATE and UPDATE (got: '${OPS}')."
  echo "      Without UPDATE, an admitted Pod can be edited into a non-compliant state."
  FAIL=1
fi

echo "--- check 2: the validation action must be Deny ---"
ACTIONS="$(kubectl get validatingpolicy "$VP_NAME" -o jsonpath='{.spec.validationActions[*]}' 2>/dev/null)"
if grep -q "Deny" <<<"$ACTIONS"; then
  echo "OK: validationActions includes Deny."
else
  echo "FAIL: validationActions is '${ACTIONS}' -- it must include Deny."
  echo "      (Enforce is ClusterPolicy vocabulary; this type takes Deny/Audit/Warn.)"
  FAIL=1
fi

echo "--- check 3: the namespace exemption must be a matchCondition, not a validation ---"
if kubectl get validatingpolicy "$VP_NAME" -o jsonpath='{.spec.matchConditions}' 2>/dev/null | grep -q .; then
  echo "OK: spec.matchConditions is present."
else
  echo "FAIL: spec.matchConditions is empty."
  echo "      The exemption must declare that the policy does not APPLY in $EXEMPT_NS,"
  echo "      rather than declaring resources there COMPLIANT inside a validations expression."
  FAIL=1
fi

echo "--- check 4: a native ValidatingAdmissionPolicy must have been generated ---"
if kubectl get validatingadmissionpolicy -o name 2>/dev/null | grep -q "vpol-${VP_NAME}"; then
  echo "OK: ValidatingAdmissionPolicy vpol-${VP_NAME} exists."
  if kubectl get validatingadmissionpolicybinding -o name 2>/dev/null | grep -q "vpol-${VP_NAME}"; then
    echo "OK: its binding exists too."
  else
    echo "FAIL: the ValidatingAdmissionPolicy exists but has no binding -- it enforces nothing."
    FAIL=1
  fi
else
  echo "FAIL: no ValidatingAdmissionPolicy named vpol-${VP_NAME} was generated."
  echo "      Set spec.autogen.validatingAdmissionPolicy.enabled: true."
  FAIL=1
fi

# Reuse the namespace across re-submits and force-delete the test Pods by name instead.
# Deleting the namespace would block on Pods still pulling images, and a re-submit issued
# while it is still Terminating cannot create anything in it.
kubectl create ns "$NS" >/dev/null 2>&1
kubectl get ns "$EXEMPT_NS" >/dev/null 2>&1 || kubectl create ns "$EXEMPT_NS" >/dev/null 2>&1

mkpod() { # name namespace image [memlimit]
  cat <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: $1
  namespace: $2
spec:
  containers:
    - name: app
      image: $3
$( [ -n "${4:-}" ] && printf '      resources:\n        limits:\n          memory: "%s"\n' "$4" )
EOF
}

echo "--- check 5: missing memory limit -> REJECTED ---"
if mkpod no-limit "$NS" nginx:1.27 | kubectl apply -f - 2>/tmp/cel110-e1 >/dev/null; then
  echo "FAIL: a Pod with no memory limit was admitted."
  FAIL=1
else
  echo "OK: rejected."
fi

echo "--- check 6: image tagged :latest -> REJECTED ---"
if mkpod latest-tag "$NS" nginx:latest 64Mi | kubectl apply -f - 2>/tmp/cel110-e2 >/dev/null; then
  echo "FAIL: a Pod using nginx:latest was admitted."
  FAIL=1
else
  echo "OK: rejected."
fi

echo "--- check 7: image with no tag at all -> REJECTED ---"
if mkpod no-tag "$NS" nginx 64Mi | kubectl apply -f - 2>/tmp/cel110-e3 >/dev/null; then
  echo "FAIL: a Pod using an untagged image was admitted -- a bare 'nginx' resolves to :latest."
  echo "      Checking only endsWith(':latest') misses this case."
  FAIL=1
else
  echo "OK: rejected."
fi

echo "--- check 8: fully compliant Pod -> ADMITTED ---"
if mkpod compliant "$NS" nginx:1.27 64Mi | kubectl apply -f - 2>/tmp/cel110-e4 >/dev/null; then
  echo "OK: admitted."
else
  echo "FAIL: a compliant Pod (explicit non-latest tag + memory limit) was rejected."
  sed 's/^/        /' /tmp/cel110-e4
  FAIL=1
fi

echo "--- check 9: a non-compliant Pod in $EXEMPT_NS -> ADMITTED ---"
if mkpod "$EXEMPT_POD" "$EXEMPT_NS" nginx | kubectl apply -f - 2>/tmp/cel110-e5 >/dev/null; then
  echo "OK: the exempt namespace was skipped."
  kubectl delete pod "$EXEMPT_POD" -n "$EXEMPT_NS" --ignore-not-found --force --grace-period=0 >/dev/null 2>&1
else
  echo "FAIL: a Pod in $EXEMPT_NS was rejected -- the exemption is missing or wrong."
  sed 's/^/        /' /tmp/cel110-e5
  FAIL=1
fi

kubectl delete ns "$NS" --ignore-not-found --wait=false >/dev/null 2>&1
rm -f /tmp/cel110-e* 2>/dev/null

if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
exit 0
