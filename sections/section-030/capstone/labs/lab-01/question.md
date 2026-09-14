# Question

Solve this question against the `kind` cluster provisioned for this lab (Kyverno is already installed and running in the `kyverno` namespace). This capstone combines the pattern-validation skills from Section 010 with this section's background-scan behavior.

The bootstrap already created a namespace called `legacy-services` with three Pods -- `legacy-svc-compliant`, `legacy-svc-noncompliant`, and `legacy-svc-latest-tag` -- and **no policy has ever governed that namespace**:

```bash
kubectl get pods -n legacy-services --show-labels
kubectl get pod legacy-svc-latest-tag -n legacy-services -o jsonpath='{.spec.containers[0].image}{"\n"}'
```

Notice that `legacy-svc-latest-tag` already carries a `team` label but is still running an unpinned `nginx:latest` image -- it predates whatever rule your team is about to write.

Write and apply one `ClusterPolicy`, in `Audit` mode with `background: true` (or left unset, since `true` is the default), containing **two rules** that together govern every Pod cluster-wide:

1. **A plain, always-on rule:** every Pod must carry a non-empty `team` label. Nothing gates this rule -- it should evaluate normally whether Kyverno is looking at a brand-new admission request or an existing Pod during a background scan.

2. **A rule gated on `request.operation`:** every container's image must not use the `:latest` tag, but -- deliberately -- **only when the Pod is being updated** (`request.operation` equals `UPDATE`), not when it is first created. Use a `preconditions` block on this rule with a `key`/`operator`/`value` check against `{{ request.operation }}`. (The intent, in a real cluster, is to allow a fleet of legacy `:latest` images to exist without being flagged at every scan, while still catching anyone who touches one of those Pods going forward.)

Do not restrict either rule to a single namespace.

Once your policy is live, read the `PolicyReport` for `legacy-services` and answer this for yourself before checking the solution: **what result does rule 2 produce for `legacy-svc-latest-tag` during the background scan -- `pass`, `fail`, or something else?** Reconcile that with what `request.operation` can possibly mean for a Pod that isn't currently being admitted by anything.
