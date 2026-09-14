# Question

Solve this question against the `kind` cluster provisioned for this lab (Kyverno is already installed and running in the `kyverno` namespace).

Write and apply a `ClusterPolicy` that:

1. Has `validationFailureAction` (or per-rule `failureAction`) set to `Enforce` — non-compliant resources must be rejected outright, not merely logged.
2. Has a single rule whose `match` block selects **only `kind: Pod`** — do not add `Deployment`, `ReplicaSet`, or any other kind to the `match` block yourself.
3. Requires every Pod to carry a non-empty `team` label.
4. Leaves autogen at its default behavior — do not add a `pod-policies.kyverno.io/autogen-controllers` annotation, and do not set it to `none`.
5. Does not restrict the policy to a single namespace; it must apply cluster-wide.

You should end up with a policy that rejects a bare non-compliant Pod, **and** — without you ever mentioning `Deployment` — also rejects a non-compliant Deployment, because Kyverno's autogen controller clones your rule to cover Pod-controller kinds automatically. You may name the policy and its rule however you like.
