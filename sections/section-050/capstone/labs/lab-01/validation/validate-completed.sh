#!/usr/bin/env bash
set -uo pipefail

SRC_NS="platform-config"
SRC_NAME="shared-ca"
NS="generation-capstone-check"
FAIL=0

kubectl delete ns "$NS" --ignore-not-found >/dev/null 2>&1
kubectl wait --for=delete "namespace/$NS" --timeout=60s >/dev/null 2>&1

if ! kubectl get clusterpolicy -o name 2>/dev/null | grep -q .; then
  echo "FAIL: no ClusterPolicy found on the cluster."
  exit 1
fi

if ! kubectl get configmap "$SRC_NAME" -n "$SRC_NS" >/dev/null 2>&1; then
  echo "FAIL: the source ConfigMap '$SRC_NAME' in namespace '$SRC_NS' is missing -- it should have been created by bootstrap."
  exit 1
fi

echo "--- check 1: creating a new Namespace triggers both generated resources ---"
kubectl create ns "$NS" >/dev/null 2>&1

NETPOL_FOUND=0
for i in $(seq 1 30); do
  if kubectl get networkpolicy default-deny-ingress -n "$NS" >/dev/null 2>&1; then
    NETPOL_FOUND=1
    break
  fi
  sleep 2
done
if [ "$NETPOL_FOUND" -eq 1 ]; then
  echo "OK: 'default-deny-ingress' NetworkPolicy was generated (data-based generation)."
else
  echo "FAIL: no 'default-deny-ingress' NetworkPolicy appeared in '$NS'."
  FAIL=1
fi

POD_SELECTOR=$(kubectl get networkpolicy default-deny-ingress -n "$NS" -o jsonpath='{.spec.podSelector}' 2>/dev/null)
POLICY_TYPES=$(kubectl get networkpolicy default-deny-ingress -n "$NS" -o json 2>/dev/null | jq -c '.spec.policyTypes | sort' 2>/dev/null)
if [ "$POD_SELECTOR" = "{}" ] && [ "$POLICY_TYPES" = '["Ingress"]' ]; then
  echo "OK: the generated NetworkPolicy has the required content (podSelector: {}, policyTypes: [Ingress])."
else
  echo "FAIL: generated NetworkPolicy content is wrong (podSelector='$POD_SELECTOR', policyTypes='$POLICY_TYPES')."
  FAIL=1
fi

CLONE_FOUND=0
INITIAL_CLONE_VALUE=""
for i in $(seq 1 30); do
  INITIAL_CLONE_VALUE=$(kubectl get configmap "$SRC_NAME" -n "$NS" -o jsonpath='{.data.ca\.crt}' 2>/dev/null)
  if [ -n "$INITIAL_CLONE_VALUE" ]; then
    CLONE_FOUND=1
    break
  fi
  sleep 2
done

SRC_VALUE=$(kubectl get configmap "$SRC_NAME" -n "$SRC_NS" -o jsonpath='{.data.ca\.crt}' 2>/dev/null)

if [ "$CLONE_FOUND" -eq 1 ] && [ "$INITIAL_CLONE_VALUE" = "$SRC_VALUE" ]; then
  echo "OK: '$SRC_NAME' ConfigMap was cloned into '$NS' with content matching the source."
else
  echo "FAIL: '$SRC_NAME' ConfigMap was not cloned into '$NS' with matching content (found='$INITIAL_CLONE_VALUE', want='$SRC_VALUE')."
  FAIL=1
fi

if [ "$CLONE_FOUND" -eq 1 ]; then
  echo "--- check 2: synchronize:true -- editing the SOURCE ConfigMap propagates to the clone ---"
  NEW_SRC_VALUE="SYNCED-VALUE-$(date +%s)"
  kubectl patch configmap "$SRC_NAME" -n "$SRC_NS" --type merge -p "{\"data\":{\"ca.crt\":\"${NEW_SRC_VALUE}\"}}" >/dev/null 2>&1

  PROPAGATED=0
  for i in $(seq 1 30); do
    CUR=$(kubectl get configmap "$SRC_NAME" -n "$NS" -o jsonpath='{.data.ca\.crt}' 2>/dev/null)
    if [ "$CUR" = "$NEW_SRC_VALUE" ]; then
      PROPAGATED=1
      break
    fi
    sleep 2
  done

  if [ "$PROPAGATED" -eq 1 ]; then
    echo "OK: editing the source ConfigMap propagated to the clone in '$NS' (synchronize:true is working)."
  else
    echo "FAIL: editing the source ConfigMap in '$SRC_NS' never propagated to the clone in '$NS'. Current clone value: '$CUR'."
    FAIL=1
  fi

  echo "--- check 3: synchronize:true -- deleting the generated clone directly gets it recreated ---"
  kubectl delete configmap "$SRC_NAME" -n "$NS" >/dev/null 2>&1

  RECREATED=0
  for i in $(seq 1 30); do
    CUR=$(kubectl get configmap "$SRC_NAME" -n "$NS" -o jsonpath='{.data.ca\.crt}' 2>/dev/null)
    if [ -n "$CUR" ]; then
      RECREATED=1
      break
    fi
    sleep 2
  done

  if [ "$RECREATED" -eq 1 ] && [ "$CUR" = "$NEW_SRC_VALUE" ]; then
    echo "OK: deleting the clone directly caused Kyverno to recreate it with content matching the (current) source."
  else
    echo "FAIL: the deleted clone was not recreated with the correct content within the timeout (found='$CUR', want='$NEW_SRC_VALUE')."
    FAIL=1
  fi
else
  echo "SKIP: checks 2 and 3 skipped because the clone never appeared."
  FAIL=1
fi

kubectl delete ns "$NS" --ignore-not-found >/dev/null 2>&1

if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
exit 0
