# Question

Solve this question against the `kind` cluster provisioned for this lab (Kyverno is already installed and running in the `kyverno` namespace).

Write and apply a `ClusterPolicy` that governs every Pod in the cluster:

1. The policy's `validationFailureAction` (or per-rule `failureAction`) must be `Enforce` — non-compliant Pods must be rejected outright, not merely logged.
2. Every Pod must carry a non-empty `team` label.
3. **Exemption:** a Pod that carries the label `tier: exempt` must be admitted even without a `team` label. You must implement this exemption with a `preconditions` block on the rule — not by narrowing `match`/`exclude` — so the check itself is skipped for exempt Pods rather than the rule simply passing them.
4. A Pod that has neither a `team` label nor `tier: exempt` must still be rejected.
5. A Pod that has a `team` label (with or without `tier: exempt`) must still be admitted.
6. Do not restrict the policy to a single namespace; it must apply cluster-wide.

You may use one rule or several, and name the policy and its rules however you like.
