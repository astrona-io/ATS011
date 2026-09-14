#!/usr/bin/env bash
set -uo pipefail

NS="generation-check"
FAIL=0

kubectl delete ns "$NS" --ignore-not-found >/dev/null 2>&1
kubectl wait --for=delete "namespace/$NS" --timeout=60s >/dev/null 2>&1

if ! kubectl get clusterpolicy -o name 2>/dev/null | grep -q .; then
  echo "FAIL: no ClusterPolicy found on the cluster."
  exit 1
fi

echo "--- check: creating a brand-new Namespace triggers generation of a NetworkPolicy ---"
kubectl create ns "$NS" >/dev/null 2>&1

FOUND=0
NETPOL_JSON=""
for i in $(seq 1 30); do
  NETPOL_JSON=$(kubectl get networkpolicy default-deny-ingress -n "$NS" -o json 2>/dev/null)
  if [ -n "$NETPOL_JSON" ]; then
    FOUND=1
    break
  fi
  sleep 2
done

if [ "$FOUND" -ne 1 ]; then
  echo "FAIL: no NetworkPolicy named 'default-deny-ingress' appeared in namespace '$NS' within 60s of creating it."
  kubectl delete ns "$NS" --ignore-not-found >/dev/null 2>&1
  exit 1
fi
echo "OK: a NetworkPolicy named 'default-deny-ingress' was generated into the new Namespace."

echo "--- check: the generated NetworkPolicy has the exact required content ---"

POD_SELECTOR=$(echo "$NETPOL_JSON" | jq -c '.spec.podSelector')
if [ "$POD_SELECTOR" = "{}" ]; then
  echo "OK: spec.podSelector is the empty selector {}."
else
  echo "FAIL: spec.podSelector was '$POD_SELECTOR', expected {} (applies to every Pod)."
  FAIL=1
fi

POLICY_TYPES=$(echo "$NETPOL_JSON" | jq -c '.spec.policyTypes | sort')
if [ "$POLICY_TYPES" = '["Ingress"]' ]; then
  echo "OK: spec.policyTypes is exactly [\"Ingress\"]."
else
  echo "FAIL: spec.policyTypes was '$POLICY_TYPES', expected [\"Ingress\"]."
  FAIL=1
fi

kubectl delete ns "$NS" --ignore-not-found >/dev/null 2>&1

if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
exit 0
