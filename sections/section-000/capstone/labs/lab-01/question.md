# Question

Kyverno is installed and the namespaces `apps` and `legacy` exist. Write one `ClusterPolicy` named `baseline` with `validationFailureAction: Enforce` and `background: false`, with three rules that all match ConfigMaps:

1. A **mutate** rule that sets the label `managed-by: platform` on every ConfigMap.
2. A **validate** rule that requires the label `managed-by: platform`. A ConfigMap created without the label must still be admitted, and must carry the label afterwards.
3. A **validate** rule that requires a non-empty `owner` label, with two exemptions: ConfigMaps in the namespace `legacy` are excluded with an `exclude` block, and a ConfigMap annotated `policy.example.com/skip-owner: "true"` is skipped with a `preconditions` block.
