# Question

Kyverno is installed. The namespace `assert-lab` exists and contains a service account named `app-sa`. Write a `ClusterPolicy` named `assert-pods` with `validationFailureAction: Enforce` and `background: false`. It needs one rule that uses `validate.assert` (not `pattern`) and matches Pods in the namespace `assert-lab`. The assertion tree must enforce all three requirements:

1. A Pod must not use the service account `default`.
2. No container may use an image that ends with `:latest`.
3. Every container must set `resources.limits.memory`.

A Pod that uses `app-sa`, the image `nginx:1.27` and a memory limit must be admitted. A Pod that breaks any one requirement must be rejected. Apply the policy to the cluster.
