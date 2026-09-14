# Question

Solve this question against the `kind` cluster provisioned for this lab (Kyverno is already installed and running in the `kyverno` namespace). This capstone combines every technique from this section's module.

Write and apply one or more `ClusterPolicy` resources, all in `Enforce` mode, that together govern every Pod cluster-wide:

1. **Ownership (OR condition):** Every Pod must satisfy at least one of:
   - a non-empty `team` label, **or**
   - a non-empty `owner` annotation.

   (Use `anyPattern` for this — it must not require both.)

2. **Per-container baseline (loop over every container):** Every container in a Pod — there may be more than one — must:
   - Set `resources.limits.cpu` and `resources.limits.memory`.
   - Use an image reference that does **not** end in the `:latest` tag.

   (Use `foreach` for this — a plain `pattern` only reliably checks a single-container Pod.)

3. Do not restrict the policy to a single namespace; it must apply cluster-wide.

You may split this across as many rules or policies as you like, and name everything however you like.
