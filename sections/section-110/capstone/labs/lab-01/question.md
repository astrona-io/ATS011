# Question

Solve this question against the `kind` cluster provisioned for this lab (Kyverno is already installed and running in the `kyverno` namespace). A namespace named **`cel-exempt`** already exists.

This capstone leaves `ClusterPolicy` behind entirely. Write and apply a **`ValidatingPolicy`** (API group `policies.kyverno.io`) that:

1. Matches **Pods** on both **`CREATE` and `UPDATE`**.
2. Denies a Pod unless **both** of these hold for **every** container:
   - it sets `resources.limits.memory`;
   - its `image` names an explicit tag that is **not** `latest` — so `nginx:1.27` is fine, while `nginx:latest` and a bare `nginx` (which resolves to `latest`) are both rejected.
3. **Exempts the `cel-exempt` namespace** — and does so by declaring that the policy *does not apply* there, rather than by folding a namespace test into the compliance expression.
4. Uses `Deny` as its validation action.
5. Instructs Kyverno to also generate a native Kubernetes **`ValidatingAdmissionPolicy`** from it.

A Pod that satisfies both checks must be admitted normally in any non-exempt namespace.

You may name the policy however you like, and may use `variables` to keep the expressions readable.

> [!TIP]
> Two of these requirements are about *which requests the policy considers at all*, and the rest are about *whether a considered request is compliant*. A `ValidatingPolicy` has separate fields for those two questions — putting a requirement in the wrong one still works, but only one of them is what the task is asking for, and the grading script can tell the difference.
