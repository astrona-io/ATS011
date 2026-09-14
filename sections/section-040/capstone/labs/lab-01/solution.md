# Solution Guide: Mutation Rules Capstone

One `ClusterPolicy`, two rules — one ordinary admission-time `patchStrategicMerge` rule for new Pods, and one `mutateExistingOnPolicyUpdate` rule with a `targets` block that reaches back into `legacy-workloads`.

---

## Step 1: Write the policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: pod-baseline-and-backfill
spec:
  rules:
    - name: inject-pod-defaults
      match:
        any:
          - resources:
              kinds:
                - Pod
      mutate:
        patchStrategicMerge:
          metadata:
            labels:
              managed-by: platform
          spec:
            containers:
              - (name): "*"
                imagePullPolicy: IfNotPresent

    - name: backfill-legacy-labels
      match:
        any:
          - resources:
              kinds:
                - Pod
              namespaces:
                - legacy-workloads
      mutate:
        mutateExistingOnPolicyUpdate: true
        targets:
          - apiVersion: v1
            kind: Pod
            namespace: legacy-workloads
        patchStrategicMerge:
          metadata:
            labels:
              managed-by: platform
```

```bash
kubectl apply -f policy.yaml
kubectl get clusterpolicy pod-baseline-and-backfill
```

If the `kyverno-background-controller` service account didn't already have `update` permission on Pods, this `kubectl apply` would be **rejected at creation time** with an error like:

```
Error from server: error when creating "policy.yaml": admission webhook "validate-policy.kyverno.svc" denied the request:
path: spec.rules[1].mutate.targets.: auth check fails, additional privileges are required for the service account
'system:serviceaccount:kyverno:kyverno-background-controller': system:serviceaccount:kyverno:kyverno-background-controller
requires permissions update for resource v1/Pod in namespace legacy-workloads
```

Kyverno performs this permission check itself, before the policy is even persisted — it will not silently accept a `mutateExistingOnPolicyUpdate` rule it knows it can't execute. This lab's bootstrap already grants that permission (see the section's course material for exactly how), so you should not see this error here — but recognizing it, and knowing it means "grant the background-controller `update` on the target kind," is worth remembering for the exam.

---

## Step 2: Why two separate rules, not one

- **`inject-pod-defaults`** is a completely ordinary mutate rule. Its `match` block is the only thing that ever triggers it, and it triggers once, at admission, for every new Pod. It has no `targets` and no `mutateExistingOnPolicyUpdate` — it cannot reach backward in time, and it was never asked to.
- **`backfill-legacy-labels`** is triggered two different ways: by its own `match` block firing at admission (so if someone updates a Pod in `legacy-workloads` normally, this rule mutates it just like any other mutate rule), *and* by `mutateExistingOnPolicyUpdate: true`, which makes Kyverno re-run this rule's `patchStrategicMerge` against every resource matching `targets` the moment this `ClusterPolicy` is itself created or updated — a completely different trigger than an admission request to the target.
- The `targets` entry only names `apiVersion`, `kind`, and `namespace` — no `name` — so it reaches *every* Pod in `legacy-workloads`, not one specific one.
- **`backfill-legacy-labels` only patches the label.** It deliberately does not also try to set `imagePullPolicy` on these Pods. That restriction isn't a Kyverno quirk — it's Kubernetes' own Pod-update validation, and it's worth walking through exactly what happens if you ignore it.

---

## Step 3: What actually happens if you try to backfill `imagePullPolicy` on an existing Pod anyway

This was tested directly while building this course, not assumed. Adding `imagePullPolicy: IfNotPresent` under `spec.containers[0]` inside the `backfill-legacy-labels` rule's `patchStrategicMerge` produces no error anywhere a user would see it — `kubectl apply -f policy.yaml` still succeeds. But for any legacy Pod whose current `imagePullPolicy` doesn't already equal `IfNotPresent`, the background controller's attempt to `Update` that Pod fails, and the failure is logged only inside the `kyverno-background-controller` Pod's own logs:

```
kubectl -n kyverno logs deploy/kyverno-background-controller | grep "failed to update target"
```

```
ERR failed to update target resource error="Pod \"legacy-pod-a\" is invalid: spec: Forbidden: pod updates may not
change fields other than `spec.containers[*].image`,`spec.initContainers[*].image`,`spec.activeDeadlineSeconds`,
`spec.tolerations` (only additions to existing tolerations),`spec.terminationGracePeriodSeconds` (allow it to be
set to 1 if it was previously negative) ..." logger=background/patch-existing-pods name=legacy-pod-a
namespace=legacy-workloads policy=pod-baseline-and-backfill
```

That message is Kubernetes' own Pod-update immutability rule, not a Kyverno error — a running Pod's container spec can basically only ever have its `image` changed after creation. Two consequences follow, and both are easy to get burned by in practice:

1. **The update is atomic per resource.** A single `Update` call carries the whole `patchStrategicMerge` fragment — labels and container fields together. If any field in that fragment represents a real change to something Kubernetes considers immutable, the *entire* update is rejected, including the otherwise-harmless label change riding along in the same patch. That's why `backfill-legacy-labels` above only ever patches `metadata.labels` — bundling the `imagePullPolicy` fragment into the *same rule* would have silently broken the label fix for `legacy-pod-a` and `legacy-pod-b` too.
2. **Nothing surfaces to any interactive session.** Unlike an admission-time rejection, which lands as a `kubectl apply` error right in your terminal, a failed existing-resource mutation just... doesn't happen, with the only trace being a log line inside the background controller. If you don't already know to go looking there, a partially-applied "mutate existing" policy can look like it worked.

This is exactly why real-world `mutateExistingOnPolicyUpdate` policies aimed at Pods almost always limit themselves to metadata (labels/annotations), or target a higher-level, fully-mutable object instead — a `Deployment`'s Pod template, a `ConfigMap`, a `Secret` — where changing the object triggers a normal, fully-supported update (and, for a `Deployment`, a rollout) rather than fighting Kubernetes' own Pod-immutability rules.

---

## Step 4: Prove both mechanisms

```bash
# The pre-existing Pods get the label within seconds of the policy being applied
kubectl get pod legacy-pod-a legacy-pod-b -n legacy-workloads --show-labels
# NAME            ...   LABELS
# legacy-pod-a    ...   managed-by=platform
# legacy-pod-b    ...   managed-by=platform    <- overridden from legacy-team

# A brand new Pod, created after the policy exists, gets both fields at admission time
kubectl run fresh-pod --image=nginx --restart=Never
kubectl get pod fresh-pod -o jsonpath='{.metadata.labels.managed-by}{"\n"}{.spec.containers[0].imagePullPolicy}'
# platform
# IfNotPresent
```

Two genuinely different trigger mechanisms, one policy: `inject-pod-defaults` only ever reacts to a real admission request; `backfill-legacy-labels` reacted the moment the policy itself was applied, reaching backward to Pods no one touched.
