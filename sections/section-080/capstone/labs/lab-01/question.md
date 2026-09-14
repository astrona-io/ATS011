# Question

Solve this question against the `kind` cluster provisioned for this lab (Kyverno is already installed and running in the `kyverno` namespace). This capstone combines both JSON Patch techniques from this section's module.

Write and apply one or more `ClusterPolicy` resources that together govern every Pod cluster-wide, using `mutate.patchesJson6902` exclusively (no `patchStrategicMerge`):

1. **Always add a required annotation:** every Pod must end up with the annotation `policy.example.com/reviewed: "true"`, whether or not it already had other annotations.
2. **Conditionally remove a disallowed annotation:** if — and only if — a Pod arrives already carrying the annotation `legacy/unmanaged-scanner`, it must be removed from the persisted object. A Pod that never had this annotation must be admitted normally; do not let a naive, unconditional `remove` operation error out the whole request for Pods that never had the field in the first place.
3. Any other annotations already present on a Pod must survive untouched.
4. Do not restrict the policy to a single namespace; it must apply cluster-wide.

You may split this across as many rules or policies as you like, and name everything however you like. Think carefully about what a JSON Patch `remove` operation needs from the target resource, and how to make the removal safe regardless of whether the field is present.
