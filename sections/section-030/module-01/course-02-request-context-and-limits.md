# Part 2: Request Context and the Limits of a Scan

## A background scan has a resource, but no request

Part 1 established the core mechanic: a background scan reads a resource exactly as it sits in the cluster and evaluates it, on a timer, with no admission request driving the check. That phrasing was doing real work, and it's time to unpack the consequence.

Every Kyverno variable under `request.*` is, in principle, describing an `AdmissionReview` -- the object the API server actually sends to a webhook at admission time. It carries the incoming resource (`request.object`), the namespace it's headed for (`request.namespace`), what kind of operation this is (`request.operation`: `CREATE`, `UPDATE`, `DELETE`, `CONNECT`), and who's making the request (`request.userInfo`, including `request.userInfo.username`). Admission time genuinely has all of this, because there's a real, live request behind the check.

A background scan has no such thing. There is no requester, no in-flight operation, nothing arriving at a webhook. Kyverno has to decide, field by field, which of these variables can be answered honestly from the resource's own persisted state, and which simply cannot exist without a live request behind them -- and it enforces that decision rather than leaving you to discover it by accident.

## What survives: request.object, request.namespace, and a synthesized request.operation

`request.object` and `request.namespace` translate cleanly: during a scan, Kyverno populates them from the resource's own current state and its own namespace field. A pattern that reads `request.object.spec.containers` behaves identically whether it's checking a brand-new admission or a two-year-old Pod, because in both cases it's just reading the object.

`request.operation` is different, and this is the detail worth testing rather than guessing. It's allowed under `background: true` -- Kyverno's own policy-validating webhook does not reject a rule for referencing it -- but during a scan there is no real operation to report, so Kyverno gives it a fixed, synthetic value: **`CREATE`**, every time, for every resource, regardless of that resource's actual history. A Pod that has been running untouched for a year is, as far as a background scan's synthesized `request.operation` is concerned, indistinguishable from one being created this instant.

Verified directly: a rule with `preconditions.all` checking `{{ request.operation }} Equals CREATE` matched *every* pre-existing Pod during a background scan and evaluated fully, producing real `pass`/`fail` results. The same rule with the precondition instead checking `Equals UPDATE` matched *none* of them -- every single pre-existing Pod came back with:

```yaml
result: skip
message: "preconditions not met"
```

Not an error. Not a crash. Not "treated as always passing." A clean, honest `skip`, because the precondition genuinely, correctly evaluates to false -- the synthesized operation is `CREATE`, and `CREATE` does not equal `UPDATE`. The rule isn't broken; it's telling you the truth about a question a background scan structurally cannot answer any other way.

You do not have to take that on trust. The playground already has two Pods in
the `legacy` namespace, neither of which is being updated by anyone. Apply a
rule gated on `UPDATE` and watch what the sweep records for them.

> [!TIP]
> **Try it — a rule the scan structurally cannot answer**
>
> ```sh
> kubectl apply -f only-on-update-policy.yaml
> kubectl get policyreport -n legacy \
>   -o jsonpath='{range .items[*]}{.scope.name}{" "}{range .results[*]}{.result}{" | "}{.message}{"\n"}{end}{end}'
> ```
>
> Expect something like:
>
> ```text
> legacy-web skip | preconditions not met
> legacy-cache skip | preconditions not met
> ```
>
> `legacy-web` has no `team` label and is plainly non-compliant, yet it comes
> back `skip`, not `fail` — the synthesized operation is `CREATE`, `CREATE` does
> not equal `UPDATE`, so the precondition is honestly false and `validate` never
> ran. Poll for a few seconds if the output is empty at first.

> [!NOTE]
> This has a sharp practical edge: a rule gated on `request.operation == UPDATE` (or `DELETE`) will *never* produce a real `fail` from a background scan, no matter how non-compliant the resource actually is. If you're relying on periodic scanning to eventually catch this kind of drift, it structurally never will -- every pass of the scanner produces `skip`, forever, because the synthesized operation never varies. The moment a real admission request touches that same resource (an actual `kubectl edit`, a label patch, anything that triggers a genuine `UPDATE`), the precondition matches for real and the rule evaluates honestly, tagged `properties.process: admission review` instead of `background scan`.

## What gets rejected outright: request.userInfo

`request.operation` is at least *allowed*, even if its scan-time value is a fixed stand-in. `request.userInfo` and its children (`request.userInfo.username`, `request.userInfo.groups`, and similar) get no such accommodation, because there is no plausible synthetic value for "who made this request" when nobody made a request. Kyverno doesn't wait for you to discover this at scan time; its own admission webhook -- the one that validates `ClusterPolicy` and `Policy` objects themselves -- rejects the policy the moment you try to apply it:

```bash
kubectl apply -f policy-with-userinfo.yaml
```

```
Error from server: error when creating "policy-with-userinfo.yaml": admission webhook
"validate-policy.kyverno.svc" denied the request: only select variables are allowed in
background mode. Set spec.background=false to disable background mode for this policy
rule: variable {{ request.userInfo.username }} is not allowed
```

This is verified, exact, current behavior -- not a warning, not a lint suggestion, a hard rejection at `kubectl apply` time. You cannot accidentally ship a background-scannable policy that silently ignores `request.userInfo`; Kyverno refuses to create the object at all.

It is worth triggering once yourself, because this is the rare case where the error message names both the problem and the fix, and recognising it later saves real time.

> [!TIP]
> **Try it — the policy webhook refusing your policy**
>
> ```sh
> kubectl apply -f policy-with-userinfo.yaml
> ```
>
> Expect something like:
>
> ```text
> Error from server: error when creating "policy-with-userinfo.yaml": admission webhook "validate-policy.kyverno.svc" denied the request: only select variables are allowed in background mode. Set spec.background=false to disable background mode for this policy rule: variable {{ request.userInfo.username }} is not allowed
> ```
>
> Note which webhook rejected it: `validate-policy.kyverno.svc`, the one that
> validates policies themselves — not `validate.kyverno.svc-fail`, the one that
> validates your workloads. No `ClusterPolicy` object was created at all. Change
> `background` to `false` and the identical file applies cleanly.

The fix is exactly what the error message says: set `spec.background: false`.

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: block-anonymous-creation
spec:
  validationFailureAction: Audit
  background: false
  rules:
    - name: check-username
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "creator was '{{ request.userInfo.username }}'"
        deny:
          conditions:
            all:
              - key: "{{ request.userInfo.username }}"
                operator: Equals
                value: "system:anonymous"
```

With `background: false`, this policy applies cleanly. It still validates every new admission normally -- `background` only controls whether *existing* resources get scanned, never whether new admission requests get checked. What it gives up is any presence in a `PolicyReport` for resources that already existed: those Pods are not scanned as `skip`, not scanned as anything -- they are simply never visited by this policy at all, permanently, unless something later triggers a real admission event against them.

> [!NOTE]
> `spec.background` is a whole-policy switch, not a per-rule one. A single `ClusterPolicy` with one rule that's perfectly fine for background scanning and a second rule that references `request.userInfo` cannot set `background: true` for the first and `false` for the second -- the entire policy is rejected at apply time if *any* rule inside it uses a disallowed variable while `spec.background` is `true`. If you need one background-scannable rule and one admission-only rule that depends on `userInfo`, they have to live in two separate `ClusterPolicy` objects.

## The scan interval

The 1-hour default mentioned in Part 1 is configurable -- it lives in the Kyverno install's ConfigMap / controller flags as `backgroundScanInterval`, and cluster operators can tune it shorter (more current reports, more load on the API server and the reports-controller) or longer. What it controls precisely is the *recurring* full re-sweep of every matching resource against every background-enabled policy. It has no bearing on the first scan after a brand-new policy becomes `Ready`, which -- as Part 1's timing note showed -- tends to happen far sooner than an hour, because Kyverno reconciles newly-applied policies against the cluster immediately rather than waiting for the next scheduled tick.
