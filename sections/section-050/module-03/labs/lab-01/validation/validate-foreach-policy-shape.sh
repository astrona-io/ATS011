#!/usr/bin/env bash
# env-configmaps uses generate.foreach
set -uo pipefail

fail() { echo "FAIL: $*"; echo "RESULT: FAIL"; exit 1; }
ok() { echo "OK: $*"; }

j=$(kubectl get clusterpolicy env-configmaps -o json 2>/dev/null) || fail "no ClusterPolicy named env-configmaps."
n=$(echo "$j" | jq -r '.spec.rules[0].generate.foreach | length // 0')
[ "$n" -ge 1 ] 2>/dev/null || fail "the rule has no generate.foreach entry."
[ "$(echo "$j" | jq -r '.spec.rules[0].generate.foreach[0].kind')" = "ConfigMap" ] || fail "the foreach entry does not generate a ConfigMap."
ok "generate.foreach is present."
echo "RESULT: PASS"
exit 0
