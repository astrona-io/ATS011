# Question

Solve this question against the `kind` cluster provisioned for this lab. Kyverno is already installed and running in the `kyverno` namespace, and the `kyverno-background-controller` service account has already been granted `update` on Pods cluster-wide (a `ClusterRole` aggregated onto it via the label `rbac.kyverno.io/aggregate-to-background-controller: "true"`) — that permission grant is infrastructure, not part of what you're being asked to write.

Before you even start, two Pods already exist in the `legacy-workloads` namespace, created before any policy governs the cluster:

- `legacy-pod-a` — carries no `managed-by` label at all.
- `legacy-pod-b` — carries `managed-by: legacy-team` (the label exists, but with the wrong value).

This capstone combines both mutation mechanisms from this section's module. Write and apply one or more `ClusterPolicy` resources, all targeting Pods cluster-wide, that together do the following:

1. **Admission-time defaults (new Pods):** Every *newly created* Pod, cluster-wide, must be given the label `managed-by: platform` and, on every one of its containers, `imagePullPolicy: IfNotPresent` — the same behavior as this section's module lab, using `mutate.patchStrategicMerge` and the `(name)` anchor for the container loop.

2. **Retroactive fix (existing Pods):** The two pre-existing Pods in `legacy-workloads` — `legacy-pod-a` and `legacy-pod-b` — must be patched to carry `managed-by: platform` once your policy exists, *without anyone touching those Pods directly*. Use `mutate.mutateExistingOnPolicyUpdate: true` together with a `mutate.targets` entry pointing at Pods in that namespace to do this.

   Scope this retroactive rule to the `managed-by` label only. Do **not** try to force `imagePullPolicy` onto these already-running Pods: a running Pod's container spec is largely immutable at the Kubernetes API level (only a small allow-list of fields — such as `spec.containers[*].image` — can ever be changed on an existing Pod), so attempting to patch `imagePullPolicy` on a Pod that is already running will be rejected by the API server itself, and — because a strategic-merge `Update` call is atomic — that rejection would silently take the label fix down with it for that Pod. The course material for this section shows this failure happening for real; you don't need to reproduce it here.

3. Do not restrict either rule to a single namespace beyond what's needed to target `legacy-workloads` for the retroactive fix; the admission-time rule (item 1) must apply cluster-wide.

You may split this across as many rules or policies as you like, and name everything however you like.
