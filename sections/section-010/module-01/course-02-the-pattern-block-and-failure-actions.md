# Part 2: The Pattern Block and What Failure Costs

Part 1 decided which resources a rule considers. This part covers the two decisions that follow: what the rule demands of them, and what happens to a resource that does not comply. They are deliberately separate fields — a pattern says *what is acceptable*, and `validationFailureAction` says *what non-compliance costs* — and keeping them separate is what lets the same rule be a report in one cluster and a hard gate in another.

## The pattern block: describing a shape, not a script

`validate.pattern` is declarative. You are not writing an `if` statement — you are drawing the resource's expected shape, and Kyverno walks the actual resource alongside your pattern, field by field, and reports the first mismatch.

Take the pattern from the skeleton above:

```yaml
pattern:
  metadata:
    labels:
      team: "?*"
```

`?*` is a wildcard meaning "one or more characters, of any value." So this pattern says: *the resource must have a `metadata.labels.team` key, and its value must be non-empty.* A Pod with `team: platform` passes. A Pod with `labels: {}` or no `team` key at all fails, because the key is missing entirely — a pattern only passes when every key it names is actually present and satisfies its value.

Kyverno's wildcard vocabulary is small and worth memorizing:

| Operator | Meaning |
| --- | --- |
| `*` | Zero or more characters (or: match anything, when used alone as a value) |
| `?` | Exactly one character |
| `?*` | One or more characters (the "must be non-empty" idiom) |
| `X \| Y` | Either literal value `X` or `Y` |

Patterns also support conditional operators on numeric-looking fields, which is how you enforce resource limits without hard-coding one exact number:

```yaml
pattern:
  spec:
    containers:
      - resources:
          limits:
            memory: "<=512Mi"
            cpu: "<=500m"
          requests:
            memory: "?*"
            cpu: "?*"
```

`<=512Mi` reads exactly like it looks: the field must exist and be less than or equal to 512Mi. The same works with `>`, `<`, `>=`, and `!` (not-equal). Kyverno recognizes Kubernetes' own quantity suffixes (`Mi`, `Gi`, `m` for millicores), so you compare quantities the way you'd write them anywhere else in a manifest.

> [!NOTE]
> Notice the skeleton only requires `requests` to be non-empty, never a specific comparison against `limits`. That's deliberate: if a container sets `resources.limits` but omits `resources.requests`, the Kubernetes API server itself fills `requests` in to match `limits` before any admission webhook — including Kyverno — ever sees the object. A rule that separately demands `resources.requests` be present adds nothing once you already require `resources.limits`; the field is guaranteed to already be populated by the time your pattern runs. This is exactly why almost every real-world Kyverno resource policy gates on `limits` and stops there.

> [!NOTE]
> A pattern targeting `spec.containers` as a plain list (as above) only fully validates when there is exactly one container, because Kyverno matches list *position* by default. Part 2 of this module covers `foreach`, which is the correct tool once a Pod can have more than one container — the pattern shown here is deliberately the simple, single-container case so the mechanic is clear before the complication is added.

With the policy from the first checkpoint still applied, the quickest way to
feel what a pattern does is to submit one Pod that satisfies it and one that
does not. Watch where the error points, not just that there was one.

> [!TIP]
> **Try it — the path in the error is the diagnostic**
>
> ```sh
> kubectl run bad-pod --image=nginx --restart=Never
> kubectl run good-pod --image=nginx --restart=Never --labels=team=platform
> ```
>
> Expect something like:
>
> ```text
> Error from server: admission webhook "validate.kyverno.svc-fail" denied the request:
>
> resource Pod/default/bad-pod was blocked due to the following policies
>
> require-team-label:
>   check-team-label: 'validation error: A team label is required on every Pod. rule check-team-label failed at path /metadata/labels/team/'
>
> pod/good-pod created
> ```
>
> The message is the exact `message` string you wrote, and `failed at path
> /metadata/labels/team/` is where the walk stopped — that path is your first
> diagnostic whenever a rule rejects something you expected it to allow.


## Enforce vs Audit: what failure actually does

`spec.validationFailureAction` decides the consequence of a pattern mismatch:

- **`Enforce`** — the admission request is rejected. `kubectl apply` returns a `Forbidden` error and the resource is never created or updated. This is a hard gate.
- **`Audit`** — the resource is allowed through anyway, but Kyverno records the failure as a result in a `PolicyReport` (namespaced resources) or `ClusterPolicyReport` (cluster-scoped resources). Nothing blocks the requester; you find out by reading the report later.

Newer Kyverno versions expose this same choice as `spec.rules[].validate.failureAction`, scoped per rule instead of per policy — useful when one policy has some rules you're ready to enforce and others you're still tuning. Either form is valid; the policy-level field is the simpler starting point and the one this module's lab uses.

`Audit` is the responsible way to introduce a new rule into a cluster that already has non-compliant resources: turn it on in `Audit`, read the `PolicyReport` entries for a while, fix what surfaces, and only then flip the policy to `Enforce`. Section 030 (Background Scans) covers how `PolicyReport` entries get generated for resources that already existed before the policy did — the `background: true` field in the skeleton above is what turns that scanning on.

Rather than take that on trust, flip the policy you already have and resubmit
the same non-compliant Pod. Two things should change: the Pod is created, and a
report object appears that did not exist a moment ago. Reports are written by
the reports controller after admission, so give it a few seconds before looking.

> [!TIP]
> **Try it — the same violation, recorded instead of blocked**
>
> ```sh
> kubectl patch clusterpolicy require-team-label --type=merge \
>   -p '{"spec":{"validationFailureAction":"Audit"}}'
> kubectl run audit-pod --image=nginx --restart=Never
> kubectl get policyreport -n default
> ```
>
> Expect something like:
>
> ```text
> pod/audit-pod created
> NAME                                   KIND   NAME        PASS   FAIL   AGE
> 399f56a0-f037-439b-9b3c-424eb75d1b3f   Pod    audit-pod   0      1      26s
> 39bcc876-9977-4cbe-bb40-f05a2702956e   Pod    good-pod    1      0      44s
> ```
>
> The Pod that was rejected a minute ago is now admitted, and the identical
> failure shows up as `FAIL 1` on a report instead. Note that `good-pod` has a
> report too, recording a `pass` — reports cover every evaluated resource, not
> only the failures.

The report name is a UUID rather than the Pod's name, so read the `NAME` column
next to `KIND` to find the resource a row is about. The full result, including
the same `message` and path you saw in the rejection, is inside:

```bash
kubectl get policyreport -n default \
  -o jsonpath='{range .items[*].results[*]}{.policy}/{.rule} {.result}: {.message}{"\n"}{end}'
# require-team-label/check-team-label fail: validation error: A team label is required on every Pod. rule check-team-label failed at path /metadata/labels/team/
# require-team-label/check-team-label pass: validation rule 'check-team-label' passed.
```

(`jsonpath` rather than piping through `jq`, so the command works whether or not
`jq` is installed on your machine.)

That is the whole `Audit` workflow: nothing blocks, and the evidence you need in
order to decide whether the rule is safe to enforce accumulates in reports.


## Section recap

A pattern is a drawing of the resource you will accept, walked field by field, passing only when every key it names is present and satisfies its value. Its wildcard vocabulary is small, and its conditional operators understand Kubernetes quantities. What a failing pattern *costs* is a separate field: `Enforce` rejects the request outright, `Audit` admits it and records the violation in a report. A plain list under a pattern is matched by position, which is the limitation Part 3 exists to fix.
