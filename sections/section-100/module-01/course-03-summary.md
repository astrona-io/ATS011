# Summary

A cleanup policy deletes resources on a schedule. It is not an admission rule. The cleanup controller runs it from a cron `schedule`. A `ClusterCleanupPolicy` works across namespaces and a namespaced `CleanupPolicy` works in one. The `match` block selects by kind, namespace and label selector.

The cleanup controller needs permission to delete the kind. Without it the policy is rejected with an error that says it has no permission to delete the kind. A `ClusterRole` with the label `rbac.kyverno.io/aggregate-to-cleanup-controller` grants it. A `conditions` block narrows the candidates further, using the `target` variable. The `cleanup.kyverno.io/ttl` label deletes a single resource after a time without any policy, but it is less expressive and fails silently when permission is missing. `deletionPropagationPolicy` decides what happens to dependents. A cleanup policy gives no exact timing guarantee, because the cron schedule sets when it runs.

Key facts:

- The cleanup controller runs cleanup policies on a cron schedule.
- RBAC for the target kind is required.
- `conditions` use the `target` variable.

<!-- astrona:playground:destroy -->
