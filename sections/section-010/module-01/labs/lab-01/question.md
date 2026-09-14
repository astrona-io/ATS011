# Question

Solve this question against the `kind` cluster provisioned for this lab (Kyverno is already installed and running in the `kyverno` namespace).

Write and apply a `ClusterPolicy` that governs every Pod in the cluster:

1. The policy's `validationFailureAction` (or per-rule `failureAction`) must be `Enforce` — non-compliant Pods must be rejected outright, not merely logged.
2. Every Pod must carry a non-empty `team` label.
3. Every container in a Pod — there may be more than one — must declare both `resources.limits.cpu` and `resources.limits.memory`.
4. Do not restrict the policy to a single namespace; it must apply cluster-wide.

You may use one rule or several, and name the policy and its rules however you like.
