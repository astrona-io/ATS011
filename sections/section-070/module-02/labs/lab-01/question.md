# Question

Kyverno is installed. The ConfigMap `limits` in the namespace `policy-config` has the key `max-replicas` with the value `3`. The namespace `ctx-lab` exists.

Write a `ClusterPolicy` named `replica-limit` with `validationFailureAction: Enforce` and `background: false` and one validate rule for Deployments in `ctx-lab`:

1. Add a `configMap` context entry named `cm` that reads `limits` from `policy-config`.
2. Add a `variable` context entry named `limit` that converts `cm.data."max-replicas"` to a number with JMESPath.
3. Use `validate.deny` to reject a Deployment whose `spec.replicas` is greater than `limit`.

The limit must come from the ConfigMap. Changing the ConfigMap must change the policy outcome without editing the policy.
