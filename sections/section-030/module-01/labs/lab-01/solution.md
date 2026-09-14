# Solution Guide: Background Scanning

This guide writes one `ClusterPolicy`, applies it, and then reads the `PolicyReport` objects Kyverno generates on its own -- no `kubectl apply` of a Pod required to see the scan work, because the whole point is that it reaches Pods that already existed.

---

## Step 1: Confirm the "before" state

```bash
kubectl get pods -n legacy-apps
# NAME                       READY   STATUS    RESTARTS   AGE
# legacy-compliant           1/1     Running   0          45s
# legacy-empty-team-label    1/1     Running   0          45s
# legacy-noncompliant        1/1     Running   0          45s

kubectl get clusterpolicy
# No resources found
```

Three Pods, zero policies. Whatever happens next has to reach backward in time to say anything about them.

---

## Step 2: Write and apply the policy

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

```bash
kubectl apply -f policy.yaml
kubectl get clusterpolicy require-team-label-audit
# NAME                       ADMISSION   BACKGROUND   READY   AGE   MESSAGE
# require-team-label-audit   true        true         True    3s    Ready
```

`validationFailureAction: Audit` means nothing this policy ever matches gets blocked. `background: true` (the default -- shown explicitly here for clarity) is what makes the rule run against resources sitting in etcd, not just new admission requests.

---

## Step 3: Poll for the PolicyReport

Background scans are not instant, but they are fast for a small cluster. In testing, the report for a freshly-applied policy against a handful of pre-existing Pods typically appeared within about 15 seconds -- well inside the one-hour default scan interval, which governs *recurring* rescans, not the first pass after a policy is created:

```bash
watch kubectl get policyreport -n legacy-apps
```

```
NAME                                   KIND   NAME                      PASS   FAIL   WARN   ERROR   SKIP   AGE
1a2b3c4d-...                           Pod    legacy-compliant          1      0      0      0       0      12s
5e6f7a8b-...                           Pod    legacy-empty-team-label   0      1      0      0       0      12s
9c0d1e2f-...                           Pod    legacy-noncompliant       0      1      0      0       0      12s
```

Each `PolicyReport` object corresponds to exactly one resource (its name is that resource's UID); `PASS`/`FAIL` count the rule results Kyverno recorded for it. Read the full detail with `-o yaml` and look at `results[]`:

```bash
kubectl get policyreport -n legacy-apps -o yaml
```

```yaml
- scope:
    apiVersion: v1
    kind: Pod
    name: legacy-noncompliant
    namespace: legacy-apps
  results:
    - policy: require-team-label-audit
      rule: check-team-label
      result: fail
      message: >-
        validation error: A team label is required on every Pod.
        rule check-team-label failed at path /metadata/labels/
      properties:
        process: background scan
```

`properties.process: background scan` is the tell -- this result was never produced by an admission request. Nobody applied `legacy-noncompliant` after the policy existed; Kyverno's background-scan controller iterated existing Pods, found this one, and recorded the failure entirely on its own.

---

## Step 4: Confirm nothing was blocked or deleted

```bash
kubectl get pods -n legacy-apps
# all three Pods are still Running, completely untouched
```

`Audit` never blocks, and a background scan is read-only by nature -- it produces a report, never a delete or an update to the scanned resource. Contrast this with what would happen to a *new* non-compliant Pod applied after the policy exists: it would still be admitted (because the policy is Audit, not Enforce), but Kyverno would also log a `fail` result for it, sourced from `properties.process: admission review` instead of `background scan` -- the same rule, evaluated by two different mechanisms depending on whether the resource is new or pre-existing.

---

## Why `background: true` (the default) is what makes this possible

If this same policy had been applied with `background: false`, the three legacy Pods would never appear in any `PolicyReport` at all -- not as `fail`, not as `pass`, not as anything. `background: false` does not mean "less strict scanning"; it means Kyverno never looks at existing resources for this policy, full stop. New Pods created or updated after the policy exists would still be validated and reported on (since admission control is a separate mechanism from background scanning), but the three Pods that already existed when you started this lab would remain permanently invisible to this policy, non-compliant or not, forever -- unless someone later re-applies (creates or updates) them, which triggers a fresh admission review.
