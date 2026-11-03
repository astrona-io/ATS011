# Summary

Admission rules only see resources when someone creates or changes them. A background scan re-evaluates validate rules against resources that already exist, so a new policy also finds old violations. The setting `spec.background` is `true` by default, and a policy with `background: false` is not scanned.

The scan writes its results to a `PolicyReport` for namespaced resources and a `ClusterPolicyReport` for cluster-scoped resources. Each entry in `results` has a status of `pass`, `fail` or `skip`. A scan has no admission request, so the variables that describe the request, such as `request.userInfo`, do not exist. Values that come from the resource, such as `request.object` and `request.namespace`, are available. A rule that depends on `request.operation` or the user cannot be evaluated the same way in a scan, and its result can differ from the admission result.

Key facts:

- Background scans run when `spec.background` is true.
- Reports are `PolicyReport` and `ClusterPolicyReport` objects.
- Request-only variables are missing during a scan.

<!-- astrona:playground:destroy -->
