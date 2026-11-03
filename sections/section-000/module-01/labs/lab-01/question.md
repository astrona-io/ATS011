# Question

Kyverno is installed. The namespaces `staging`, `production` and `sandbox` exist. The platform team wants two ConfigMap rules rolled out in different ways.

1. In the namespace `staging` only, create a namespaced `Policy` named `require-owner` that **rejects** any ConfigMap without a non-empty `owner` label.
2. Create a `ClusterPolicy` named `require-cost-center` with one validate rule that requires a non-empty `cost-center` label on every ConfigMap. The rule must **audit** by default (the request is admitted) and **enforce** only in the namespace `production`. Use failure action overrides.
3. A ConfigMap in `production` without `owner` must still be admitted, because the namespaced policy does not apply there.

Set `background: false` on both policies so that only admission is graded.
