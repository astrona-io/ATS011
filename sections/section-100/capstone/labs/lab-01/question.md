# Question

Solve this question against the `kind` cluster provisioned for this lab (Kyverno is already installed and running in the `kyverno` namespace). Two namespaces already exist: **`capstone-cleanup`** and **`capstone-keep`**.

This capstone combines both techniques from this section's module: RBAC for a kind other than Pod, and filtering that `match` alone cannot express.

Make Kyverno sweep expired scratch ConfigMaps — carefully:

1. Grant Kyverno's cleanup controller the permissions it needs to delete **ConfigMaps**.
2. Write and apply a `ClusterCleanupPolicy` that runs on a **one-minute** cron schedule and deletes a ConfigMap only when **all** of the following are true:
   - it lives in the **`capstone-cleanup`** namespace;
   - it carries the label **`lifecycle: ephemeral`**;
   - it does **not** carry the annotation **`example.com/retain: "true"`**.
3. Everything else must survive untouched — in particular:
   - a labelled ConfigMap in `capstone-cleanup` that *does* carry `example.com/retain: "true"`;
   - an unlabelled ConfigMap in `capstone-cleanup`;
   - a labelled ConfigMap in `capstone-keep`.

An annotation is not something a Kubernetes label selector can filter on, so the retain exemption cannot live in `match`. Think about which part of the policy is evaluated by the API server when listing candidates, and which part is evaluated per-resource by Kyverno afterwards — and what variable the latter has available to it.

You may name the policy and any RBAC objects however you like.

> [!NOTE]
> Deletion happens on cron boundaries, so expect to wait up to a minute after creating a test ConfigMap. The grading script accounts for this and may take a couple of minutes to finish.
