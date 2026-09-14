# Part 1: What Background Scanning Actually Does

## Admission control only ever looks at the door

Every rule from Section 010 fires at exactly one moment: when the API server hands an incoming object to Kyverno's admission webhook, before that object is persisted. That's the entire job of admission control -- accept or reject a specific request, right now, and never again. Once a Pod is sitting in etcd, admission control has nothing further to say about it. Nobody re-runs the webhook against a Pod that isn't currently being created, updated, or deleted.

That leaves an obvious hole: what about everything that was already running when your policy was written? A cluster is never a blank slate. By the time anyone gets around to writing "every Pod needs a `team` label," there are already hundreds of Pods without one, quietly working, never touched by any admission request, and therefore invisible to a purely admission-based rule forever.

`spec.background` is Kyverno's answer to that hole. It defaults to `true`, and it is not a variant of admission control -- it's a second, independent mechanism:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-team-label-audit
spec:
  validationFailureAction: Audit
  background: true
  rules:
    - name: check-team-label
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "A team label is required on every Pod."
        pattern:
          metadata:
            labels:
              team: "?*"
```

With `background: true`, Kyverno periodically lists every resource matching this rule's `match` block -- not just newly-admitted ones, *all* of them, including the ones that have existed since before this policy was ever applied -- and evaluates the same `validate.pattern` against each one. There is no incoming admission request driving this. Kyverno reads the resource exactly as it currently sits in the cluster and checks it against your pattern, the same field-by-field walk from Section 010, just triggered by a timer instead of a `kubectl apply`.

## Where the results go: PolicyReport and ClusterPolicyReport

An admission-time rejection produces an error message printed straight to the terminal that ran `kubectl apply`. A background scan has no terminal to print to -- nobody is sitting there waiting for the result. Instead, Kyverno writes every scan result into a report object:

| Resource being evaluated | Report kind |
| --- | --- |
| Namespaced (Pod, Deployment, ConfigMap, ...) | `PolicyReport`, created in that resource's own namespace |
| Cluster-scoped (Namespace, ClusterRole, ...) | `ClusterPolicyReport` |

```bash
kubectl get policyreport -A
kubectl get clusterpolicyreport
```

Every `PolicyReport` object corresponds to exactly one resource -- its name is that resource's UID, not something you'll ever type by hand. Read the full detail with `-o yaml` and look at `scope` (which resource this is) and `results[]` (one entry per rule that evaluated it):

```bash
kubectl get policyreport -n legacy-apps -o yaml
```

```yaml
- apiVersion: wgpolicyk8s.io/v1alpha2
  kind: PolicyReport
  metadata:
    name: f2749fb4-2673-4add-904e-17ff6c75a7ee
    namespace: legacy-apps
  scope:
    apiVersion: v1
    kind: Pod
    name: pre-existing-noncompliant
    namespace: legacy-apps
    uid: f2749fb4-2673-4add-904e-17ff6c75a7ee
  summary:
    pass: 0
    fail: 1
    warn: 0
    error: 0
    skip: 0
  results:
    - policy: require-team-label-audit
      rule: check-team-label
      result: fail
      message: >-
        validation error: A team label is required on every Pod.
        rule check-team-label failed at path /metadata/labels/
      properties:
        process: background scan
      source: kyverno
```

`properties.process: background scan` is the detail worth noticing: it tells you exactly which mechanism produced this result. The same rule can also produce an identical-looking `fail` entry stamped `admission review`, when the result came from the webhook rather than a sweep. One policy, one rule, two completely different triggers, both landing in the same report format.

> [!NOTE]
> Do not read that stamp as a reliable record of *how a particular resource first got here*. Verified on v1.19.1: with `background: true`, a Pod created **after** the policy existed — which really did go through admission — still ends up stamped `background scan`, because the next sweep recomputes its result and overwrites the entry. Set `background: false` on the same `Audit` policy and the same Pod's entry reads `admission review` and stays that way. The field tells you which mechanism most recently wrote the entry, not which one first noticed the resource.

`results[].result` is one of a small vocabulary: `pass`, `fail`, `warn`, `error`, and `skip`. You've already met `pass` and `fail` from Section 010's admission-time errors. `skip` is new here, and Part 2 of this module is entirely about the one situation where a background scan reliably produces it.

The playground makes this concrete without any setup on your part: two Pods are
already running in the `legacy` namespace before you apply anything.
`legacy-cache` carries `team=platform`; `legacy-web` carries no labels at all.
Neither has ever been seen by an admission webhook that cared.

Apply the skeleton policy above and then poll — the first sweep is not instant,
and polling rather than assuming a fixed delay is the habit worth building.

> [!TIP]
> **Try it — a verdict on Pods that predate the policy**
>
> ```sh
> kubectl get pods -n legacy --show-labels
> kubectl apply -f policy.yaml
> kubectl get policyreport -n legacy
> ```
>
> Expect something like:
>
> ```text
> legacy-cache   1/1   Running   0   6s   team=platform
> legacy-web     1/1   Running   0   6s   <none>
>
> clusterpolicy.kyverno.io/require-team-label-audit created
>
> NAME                                   KIND   NAME           PASS   FAIL   AGE
> 078747fe-15ef-4a74-8222-3c7c082a8bea   Pod    legacy-cache   1      0      1s
> 37d4f5ed-3c02-45af-8d33-01eb6fd25554   Pod    legacy-web     0      1      1s
> ```
>
> Nobody applied `legacy-web` after the policy existed — the playground created
> it during startup, before any policy was on the cluster. The `fail` appeared
> entirely on its own, from a sweep.

If `kubectl get policyreport -n legacy` comes back empty, wait and run it again
rather than concluding it does not work; the first entries take time to show up.
Once they do, the `properties.process` field confirms where they came from:

```bash
kubectl get policyreport -n legacy \
  -o jsonpath='{range .items[*]}{.scope.name}{" "}{range .results[*]}{.result}{" ("}{.properties.process}{")\n"}{end}{end}'
# legacy-cache pass (background scan)
# legacy-web fail (background scan)
```

> [!NOTE]
> Kyverno's background-scan controllers log a configured interval of `1h` by default -- and that number is real; it governs how often a *settled* policy gets fully re-swept against the whole cluster. But it is not how long you wait the first time. Verified while building this course, the very first `PolicyReport` entries for a newly-applied policy against a couple of pre-existing Pods appeared in well under 30 seconds. Read the 1-hour figure as "how often this keeps happening in the background afterward," not "how long you'll wait to see it work" -- and always poll for the report rather than assuming a fixed delay, since the exact timing depends on how busy the reports controller already is.

## Enforce, Audit, and background scanning are three separate questions

It's worth being precise about what background scanning does *not* change: `spec.validationFailureAction` (`Enforce` vs `Audit`) governs what happens to a resource at admission time only. Background scanning happens regardless of which one you chose -- an `Enforce` policy still only blocks *new* admission requests; any Pod that already existed before the policy was applied is just as invisible to enforcement as it would be under `Audit`, because enforcement isn't a scan, it's a gate, and a gate can't reach backward. What `Enforce` changes is what happens to a *new* non-compliant Pod applied after the policy exists (rejected instead of merely reported); it does nothing whatsoever to Pods that predate the policy.

This is exactly why `Audit` combined with `background: true` is the standard, responsible way to introduce a brand-new rule into a cluster that already has non-compliant resources living in it: nothing gets blocked, nothing gets deleted, and you get a complete, queryable inventory of every existing violation to work through before you ever consider flipping the policy to `Enforce`.
