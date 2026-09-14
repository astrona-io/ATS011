# Question

Solve this question against the `kind` cluster provisioned for this lab (Kyverno is already installed and running in the `kyverno` namespace). This capstone raises the bar on this section's module: instead of one precondition, you must combine two of them with AND logic.

Write and apply a `ClusterPolicy` that governs every Pod in the cluster:

1. The policy's `validationFailureAction` (or per-rule `failureAction`) must be `Enforce`.
2. Every Pod must carry a non-empty `team` label.
3. **The rule must only ever run when *both* of the following hold, using a single `preconditions.all` block (logical AND):**
   - the incoming admission request's operation is `CREATE` (never `UPDATE`), **and**
   - the request's namespace is not `trusted-automation`.

   In other words: a `CREATE` in `trusted-automation` is exempt, and so is *any* `UPDATE` anywhere (including one that removes an existing `team` label from a Pod created before this policy existed) — both because at least one of the two AND'd conditions is false in each case.
4. A `CREATE` of a non-compliant Pod outside `trusted-automation` must still be rejected.
5. A `CREATE` of a compliant Pod outside `trusted-automation` must still be admitted.
6. Do not restrict the policy to a single namespace beyond the `trusted-automation` exemption; it must otherwise apply cluster-wide.

You may use one rule or several, and name the policy and its rules however you like.
