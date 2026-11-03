#!/usr/bin/env bash
# share-config uses cloneList
set -uo pipefail

fail() { echo "FAIL: $*"; echo "RESULT: FAIL"; exit 1; }
ok() { echo "OK: $*"; }

j=$(kubectl get clusterpolicy share-config -o json 2>/dev/null) || fail "no ClusterPolicy named share-config."
c='.spec.rules[0].generate.cloneList'
[ "$(echo "$j" | jq -r "$c.namespace")" = "shared-config" ] || fail "cloneList.namespace is not shared-config."
echo "$j" | jq -e "$c.kinds | index(\"v1/ConfigMap\")" >/dev/null || fail "cloneList.kinds does not contain v1/ConfigMap."
[ "$(echo "$j" | jq -r "$c.selector.matchLabels.share")" = "true" ] || fail "cloneList.selector.matchLabels.share is not \"true\"."
[ "$(echo "$j" | jq -r '.spec.rules[0].generate.synchronize')" = "true" ] || fail "generate.synchronize is not true."
ok "cloneList settings are correct."
echo "RESULT: PASS"
exit 0
