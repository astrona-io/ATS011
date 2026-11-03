# Question

Kyverno is installed. The namespaces `team-a` and `team-b` already exist and are labelled `tier=standard`. The namespace `scratch` exists and has no `tier` label. The background controller is allowed to manage ConfigMaps.

Write a `ClusterPolicy` named `standard-defaults` with one generate rule that triggers on Namespaces labelled `tier=standard`:

1. Generate a ConfigMap named `platform-defaults` in the new namespace, with a data key `log-level` set to `info`.
2. The rule must also apply to namespaces that **already exist** when the policy is applied.
3. Keep the downstream ConfigMap in sync with the policy, and keep the ConfigMap in place if the policy is deleted later.

`team-a` and `team-b` must receive the ConfigMap. `scratch` must not.
