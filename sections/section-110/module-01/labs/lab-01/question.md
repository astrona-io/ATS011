# Question

Solve this question against the `kind` cluster provisioned for this lab (Kyverno is already installed and running in the `kyverno` namespace).

Write and apply a `ClusterPolicy` that governs every Pod cluster-wide:

1. The rule must validate using a **`validate.cel` expression** — not `validate.pattern`, not `validate.deny`, not `foreach`.
2. The expression must require that **every container** in the Pod sets `spec.containers[].resources.limits.memory`. A Pod where even one container omits it must be rejected.
3. The policy must be in **`Enforce`** mode so violations are blocked rather than merely reported.
4. A Pod that has **no `resources` block at all** must be rejected with **your own failure message** — not with a CEL evaluation error. Think about what CEL does when you index into a field that is not there.
5. **Deleting a Pod must keep working.** A rule that matches Pods and says nothing about operations is consulted on `DELETE` too — and on a `DELETE` there is no incoming object for your expression to read.

You may name the policy and its rule however you like.

> [!TIP]
> Test with a **two-container** Pod where only the first container sets a limit. A single-container test will pass even with an expression that only ever inspects `containers[0]`.
