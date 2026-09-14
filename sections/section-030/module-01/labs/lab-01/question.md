# Question

Solve this question against the `kind` cluster provisioned for this lab (Kyverno is already installed and running in the `kyverno` namespace).

Before you even look at this file, the bootstrap already created a namespace called `legacy-apps` with three Pods living in it -- `legacy-compliant`, `legacy-noncompliant`, and `legacy-empty-team-label` -- and **no policy has ever governed that namespace**. Confirm this for yourself:

```bash
kubectl get pods -n legacy-apps
kubectl get clusterpolicy
```

Your task:

Write and apply a `ClusterPolicy` that governs every Pod in the cluster:

1. Every Pod must carry a non-empty `team` label.
2. The policy's `validationFailureAction` (or per-rule `failureAction`) must be `Audit` -- non-compliant Pods must never be blocked, only reported on.
3. `spec.background` must be `true` (or simply left unset, since `true` is the default) so the rule is evaluated against resources that already exist, not only new admission requests.
4. Do not restrict the policy to a single namespace; it must apply cluster-wide.

Once your policy is live, prove that the background scan reached back in time and evaluated the three pre-existing `legacy-apps` Pods -- resources that existed before your policy did -- by reading the `PolicyReport` objects Kyverno generates for that namespace:

```bash
kubectl get policyreport -n legacy-apps
kubectl get policyreport -n legacy-apps -o yaml
```

You should be able to point to a `fail` result for `legacy-noncompliant` and `legacy-empty-team-label`, and a `pass` result for `legacy-compliant` -- all without any of the three Pods ever having been touched, deleted, or blocked.
