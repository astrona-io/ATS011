# Question

Solve this question against the `kind` cluster provisioned for this lab (Kyverno is already installed and running in the `kyverno` namespace).

Make Kyverno automatically delete short-lived Pods cluster-wide:

1. Grant Kyverno's cleanup controller the Kubernetes permissions it needs to delete Pods. It has none by default, and will refuse your policy until it does.
2. Write and apply a `ClusterCleanupPolicy` that:
   - selects **Pods carrying the label `lifecycle: ephemeral`**, in any namespace;
   - runs on a **one-minute** cron schedule.
3. A Pod that does not carry `lifecycle: ephemeral` must be left completely alone.

You may name the policy and any RBAC objects however you like.

> [!NOTE]
> Deletion happens on cron boundaries, so after creating a test Pod expect to wait up to a minute before it disappears. The grading script accounts for this and may take a couple of minutes to finish.
