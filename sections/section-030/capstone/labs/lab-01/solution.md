# Solution Guide: Background Scans Capstone

One `ClusterPolicy`, two rules -- one plain, one gated on `request.operation` -- to show that the two behave differently the moment there is no live admission request to gate on.

---

## Step 1: Write the policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: legacy-services-baseline
spec:
  validationFailureAction: Audit
  background: true
  rules:
    - name: require-team-label
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

    - name: no-latest-tag-on-update
      match:
        any:
          - resources:
              kinds:
                - Pod
      preconditions:
        all:
          - key: "{{ request.operation }}"
            operator: Equals
            value: "UPDATE"
      validate:
        message: "Updated Pods must not use the ':latest' image tag."
        foreach:
          - list: "request.object.spec.containers"
            pattern:
              image: "!*:latest"
```

```bash
kubectl apply -f policy.yaml
kubectl get clusterpolicy legacy-services-baseline
```

---

## Step 2: Read the reports and see the two rules diverge

```bash
kubectl get policyreport -n legacy-services -o yaml
```

For `legacy-svc-latest-tag` (team label present, image is `nginx:latest`), the `results[]` array looks like this once the scan completes:

```yaml
results:
  - policy: legacy-services-baseline
    rule: require-team-label
    result: pass
    message: "validation rule 'require-team-label' passed."
    properties:
      process: background scan

  - policy: legacy-services-baseline
    rule: no-latest-tag-on-update
    result: skip
    message: "rule no-latest-tag-on-update skipped: [preconditions not met]"
    properties:
      process: background scan
```

`require-team-label` passes normally -- it has no precondition, so it evaluates the resource's own persisted fields (`request.object` is populated correctly during a background scan, because it's just the resource as it sits in etcd) exactly the way it would at admission time.

`no-latest-tag-on-update` does **not** fail, even though this Pod is unambiguously running `:latest`. It **skips**, and the reason is `preconditions not met`.

---

## Step 3: Why `request.operation` makes this rule skip instead of fail

There is no real admission request behind a background scan -- nothing is being created, updated, or deleted at the moment Kyverno evaluates an existing resource on a timer. Kyverno cannot leave `request.operation` empty (some engine code paths assume it is always set), so during a background scan it is populated with a synthetic value: **`CREATE`**, unconditionally, for every resource the scanner visits, regardless of that resource's real history.

That single fact has two consequences, and this lab's policy deliberately triggers both, depending on which comparison you write:

- A precondition checking `request.operation == CREATE` would be satisfied by *every* resource in *every* background scan -- it is never a meaningful filter during a scan, since the synthetic value never varies.
- A precondition checking `request.operation == UPDATE` (or `DELETE`) -- what this lab's rule 2 uses -- is **never** satisfied during a background scan, because the synthetic value is always `CREATE`. The rule is not broken and does not error; its precondition simply, correctly, evaluates to false every single time, and Kyverno reports that as `skip`.

In other words: this rule is not "less effective" during a background scan -- it is **entirely inert**. It will never produce a `fail` result for any pre-existing resource, no matter how obviously non-compliant, for as long as background scanning is what's evaluating it. The only way this rule ever produces a real `fail` is a genuine admission-time `UPDATE` -- for example, patching a label on `legacy-svc-latest-tag` after the policy exists triggers a real `UPDATE` admission review, `request.operation` now genuinely equals `UPDATE`, the precondition matches for real, and the (unchanged) `:latest` image now legitimately fails the pattern, recorded with `properties.process: admission review` instead of `background scan`. Try it:

```bash
kubectl label pod legacy-svc-latest-tag -n legacy-services probe=1 --overwrite
```

---

## Step 4: The lesson, stated plainly

`background: true` does not mean "every rule in this policy gets fully re-checked against every existing resource." It means "Kyverno will attempt to re-evaluate every rule against every existing resource, using only that resource's own persisted state plus a small, fixed set of synthesized request fields." A rule written to care about *how* a resource is being touched (`request.operation`, and even more so anything under `request.userInfo`, which Kyverno's own policy-admission webhook refuses outright under `background: true` -- see this module's Part 2) can only ever answer that question honestly during a real admission request. Relying on a background scan to eventually catch a rule like `no-latest-tag-on-update` is relying on something that structurally cannot happen: no scan will ever manufacture a fake `UPDATE` for you.

If a rule's entire purpose is to react to *how* a resource arrived (not what it currently looks like), the honest choice is `spec.background: false` for that rule's policy -- an explicit admission that this check only ever means anything at admission time -- rather than leaving `background: true` and silently collecting `skip` results forever.
