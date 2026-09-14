# Question

Solve this question against the `kind` cluster provisioned for this lab (Kyverno is already installed and running in the `kyverno` namespace). The namespace `cap-a` already exists and already has **two** Pods running in it before you write anything. This capstone combines both variable mechanisms from this section's module in one policy.

Write and apply a `ClusterPolicy`, in `Enforce` mode, that governs every Pod cluster-wide:

1. **Live quota (context.apiCall):** Use a `context.apiCall` entry that calls the Kubernetes API to count how many Pods **already exist in the namespace of the Pod currently being admitted** (`urlPath` must reference `{{request.namespace}}`, not a hardcoded namespace). Deny the incoming Pod if that namespace already has **3 or more** Pods.
2. **Named rejection (context.variable):** Use a **second** `context` entry, of type `variable`, that extracts the incoming Pod's own name from the resource via JMESPath (`request.object.metadata.name`). Your rule's `validate.message` must use that variable so a rejected request's error names the actual Pod that was rejected — not a generic sentence.
3. The rule must match every `Pod`, cluster-wide — do not restrict it to `cap-a` or any other single namespace.
4. Restrict the rule's `match` to the `CREATE` operation only (`match.resources.operations: [CREATE]`). Do not leave `operations` unset.
5. Exclude the `kube-system`, `kyverno`, and `local-path-storage` namespaces from the rule.

You may name the policy, its rule, and both `context` entries however you like — but the message must genuinely depend on the `variable` context entry (grading will check that a rejected Pod's own name appears in the returned error), and the admit/reject decision must genuinely depend on the `apiCall` context entry (grading will check the decision changes correctly across two differently-seeded namespaces).

> [!NOTE]
> Requirement 4 is not busywork — it was discovered by testing, not assumed. A rule with no `operations` restriction also evaluates on DELETE. Since the quota check compares "is the namespace's live Pod count already at or over the limit," an over-limit namespace can never have any of its own Pods deleted through the normal API if the rule isn't scoped to `CREATE` — every delete attempt re-runs the same `apiCall`, sees the namespace is still over quota, and denies the delete too, which can hang a `kubectl delete ns` indefinitely. Scoping to `CREATE` avoids this entirely.
