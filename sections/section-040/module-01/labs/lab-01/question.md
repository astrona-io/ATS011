# Question

Solve this question against the `kind` cluster provisioned for this lab (Kyverno is already installed and running in the `kyverno` namespace).

Write and apply a `ClusterPolicy` with a `mutate` rule that governs every Pod cluster-wide:

1. Every incoming Pod must be given the label `managed-by: platform`, whether or not it already carries a `managed-by` label of its own.
2. Every container in the Pod — there may be more than one — must be given `imagePullPolicy: IfNotPresent`, whether or not it already sets its own `imagePullPolicy`.
3. Use `mutate.patchStrategicMerge` to do this (not a JSON patch). Remember that a plain list entry under `patchStrategicMerge` is matched by position — to reach *every* container regardless of how many a Pod has, you need the anchor syntax that applies a patch fragment to every element of a list.
4. Do not restrict the policy to a single namespace; it must apply cluster-wide.

You may name the policy and its rule however you like. Do not set `spec.background` — this rule only needs to act at admission time.
