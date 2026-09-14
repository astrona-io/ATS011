# Part 2: Mutating Existing Resources

## Everything so far has one blind spot

Part 1's `mutate` rules, like every rule in Section 010, only ever act on an admission request — a `kubectl apply` or a controller's own create/update call, arriving right now, for the resource named in `match`. That leaves exactly the same hole Section 030 identified for `validate`: every resource that already existed before your policy was written is completely invisible to it. A brand-new Pod gets `managed-by: platform` injected the instant it's created. A Pod that's been running for six months, without that label, just keeps running without it — forever, unless someone updates it directly.

`mutate.mutateExistingOnPolicyUpdate` is Kyverno's answer, and it's worth being precise about what triggers it, because it is genuinely a different mechanism from everything in Part 1, not a variant of it.

## targets: naming what gets mutated, separately from what triggers it

An ordinary mutate rule's `match` block does two jobs at once: it decides which resources trigger the rule, *and* it decides which resource gets patched (always the same one — the one in the admission request). A mutate-existing rule splits those two jobs apart:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: backfill-legacy-labels
spec:
  rules:
    - name: patch-existing-pods
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

`match` is still required, and it still triggers this rule normally at admission time — a real create or update of a Pod in `legacy-workloads` gets patched exactly like Part 1's rules. But `mutate.targets` is new: it names a *separate* set of resources — here, every Pod in `legacy-workloads`, since no `name` is given — that this rule reaches out and patches whenever `mutateExistingOnPolicyUpdate: true` fires. And that field fires on an event Part 1 never mentioned: **the `ClusterPolicy` itself being created or updated.** Not a new Pod arriving. The policy changing.

This is the whole point: you can `kubectl apply` this `ClusterPolicy` today, on a cluster where `legacy-workloads` already has Pods that have existed for a year, and those Pods get patched — not because anyone touched them, but because the policy that governs them just changed.

## Verified live: the permission Kyverno insists on first

Applying a `mutateExistingOnPolicyUpdate` rule for the first time, on a cluster where nothing has pre-granted the right permission, produces this exact rejection — captured directly while building this course, not paraphrased from documentation:

```
Error from server: error when creating "policy.yaml": admission webhook "validate-policy.kyverno.svc" denied the request:
path: spec.rules[0].mutate.targets.: auth check fails, additional privileges are required for the service account
'system:serviceaccount:kyverno:kyverno-background-controller': system:serviceaccount:kyverno:kyverno-background-controller
requires permissions update for resource v1/Pod in namespace legacy-workloads
```

Kyverno's own admission webhook checks, at the moment you apply the policy, whether the `kyverno-background-controller` service account actually has permission to `update` every kind named in `targets`. If it doesn't, the policy is rejected outright — Kyverno refuses to accept a mutate-existing rule it already knows it can't execute, rather than accepting it and failing silently later.

The playground deliberately ships without that grant, so you can meet the refusal before you meet the fix. Write the rule against the `legacy` namespace the playground already populated, and apply it.

> [!TIP]
> **Try it — refused before it can do any harm**
>
> ```sh
> kubectl apply -f mutate-existing-policy.yaml
> ```
>
> Expect something like:
>
> ```text
> Error from server: error when creating "mutate-existing-policy.yaml": admission webhook "validate-policy.kyverno.svc" denied the request: path: spec.rules[0].mutate.targets.: auth check fails, additional privileges are required for the service account 'system:serviceaccount:kyverno:kyverno-background-controller': system:serviceaccount:kyverno:kyverno-background-controller requires permissions update for resource v1/Pod in namespace legacy
> ```
>
> The rejecting webhook is `validate-policy.kyverno.svc` — the one that validates
> policies, not workloads — and no `ClusterPolicy` was created. The message names
> the service account, the verb, the kind, and the namespace it needs them in.

The fix is an RBAC grant, and the way you deliver it matters: Kyverno's own `kyverno:background-controller` `ClusterRole` is an **aggregated** role, built by combining every `ClusterRole` in the cluster that carries the label `rbac.kyverno.io/aggregate-to-background-controller: "true"`. You don't edit Kyverno's own role directly — you add a new `ClusterRole` carrying that label, and Kubernetes' own aggregation controller folds its rules in automatically:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kyverno-background-controller-pods
  labels:
    rbac.kyverno.io/aggregate-to-background-controller: "true"
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch", "update", "patch"]
```

Apply that, and the exact same `mutateExistingOnPolicyUpdate` policy that was rejected moments ago is accepted immediately — no restart of any Kyverno component required, since the aggregation is a live Kubernetes RBAC feature, not something Kyverno itself has to reload.

Now re-run the apply that just failed, and watch two Pods nobody touched acquire a label.

> [!TIP]
> **Try it — the same file, accepted, and Pods change underneath you**
>
> ```sh
> kubectl apply -f background-controller-rbac.yaml
> kubectl get pods -n legacy --show-labels
> kubectl apply -f mutate-existing-policy.yaml
> kubectl get pods -n legacy --show-labels
> ```
>
> Expect something like:
>
> ```text
> legacy-cache   1/1   Running   0   26s   team=platform
> legacy-web     1/1   Running   0   26s   <none>
>
> clusterpolicy.kyverno.io/label-legacy-pods created
>
> legacy-cache   1/1   Running   0   29s   managed-by=platform,team=platform
> legacy-web     1/1   Running   0   29s   managed-by=platform
> ```
>
> Neither Pod was recreated — the `AGE` column barely moved. No admission request
> touched them. The trigger was the `ClusterPolicy` being created. If the second
> `--show-labels` still shows the old state, run it again; this took about three
> seconds while building this course, but it is asynchronous.

## How fast, and where it actually happens

Once the permission exists, timing this end-to-end (also done directly, not estimated): applying a `mutateExistingOnPolicyUpdate` policy against two pre-existing Pods produced the `managed-by: platform` label on both of them **within a few seconds** — nowhere near the hourly reconciliation interval Kyverno documents as its background-scan default. That hourly figure describes how often a *settled* mutate-existing rule gets force-reconciled afterward, the same way Section 030 found for background scans — not how long the very first pass takes after you apply or update the policy. Read it the same way: poll for the result, don't assume a fixed delay, and don't be surprised when it's fast.

## The limit that actually matters: not every field on an existing resource is mutable

Here is the finding most worth internalizing, because it will bite you exactly once in production if you don't know it going in — and it was discovered directly, by trying it, while building this course.

Take the policy above and add a container-level field to the same `patchStrategicMerge` used for the existing-resource target:

```yaml
patchStrategicMerge:
  metadata:
    labels:
      managed-by: platform
  spec:
    containers:
      - (name): "*"
        imagePullPolicy: IfNotPresent
```

`kubectl apply -f policy.yaml` still succeeds — no error anywhere a user would see. But for any pre-existing Pod whose `imagePullPolicy` doesn't already equal `IfNotPresent`, the label never gets added either. The only trace is a log line, inside the `kyverno-background-controller` Pod itself:

```
ERR failed to update target resource error="Pod \"legacy-pod-a\" is invalid: spec: Forbidden: pod updates may not
change fields other than `spec.containers[*].image`,`spec.initContainers[*].image`,`spec.activeDeadlineSeconds`,
`spec.tolerations` (only additions to existing tolerations),`spec.terminationGracePeriodSeconds` (allow it to be
set to 1 if it was previously negative) ..." logger=background/patch-existing-pods name=legacy-pod-a
namespace=legacy-workloads policy=backfill-legacy-labels
```

That message comes from Kubernetes itself, not Kyverno — a running Pod's `spec` is almost entirely immutable after creation. The API server allows updates to a short, fixed allow-list of fields (essentially: a container's `image`, `activeDeadlineSeconds`, additions to `tolerations`, and `terminationGracePeriodSeconds` moving off a negative value) and rejects everything else, unconditionally, for any client — `kubectl edit`, a controller, or Kyverno's own background controller acting on your behalf. `imagePullPolicy` was never on that list.

Two consequences follow directly from this, and both are easy to miss:

1. **The update is atomic per resource.** One `patchStrategicMerge` fragment becomes one API `Update` call. If any part of that fragment represents an actual change to a field Kubernetes considers immutable, the *entire* call is rejected — including a perfectly legal label change riding along in the same fragment. A Pod whose `imagePullPolicy` already happened to equal `IfNotPresent` (no real change requested) would still get its label updated just fine; a Pod that genuinely needed the value changed loses the label fix too, silently, as collateral damage from the same rejected call.
2. **Nothing surfaces anywhere a person is normally looking.** An admission-time rejection lands as an error in the very terminal that ran `kubectl apply`. A mutate-existing rejection happens entirely inside the background controller, asynchronously, with no requester waiting for a response — the only way to discover it is to already know to check that controller's logs.

This is exactly why real `mutateExistingOnPolicyUpdate` policies aimed at Pods almost always restrict themselves to metadata — labels and annotations are always mutable, on any object, at any time — or target a fully-mutable higher-level object instead, like a `Deployment`'s Pod template (changing it triggers a normal rolling update), a `ConfigMap`, or a `Secret`. If you find yourself wanting to backfill a container-level field onto Pods that already exist, the honest options are: wait for those Pods to be replaced naturally by their controller, or force that replacement yourself (e.g. a rolling restart) — not ask Kyverno to rewrite a running Pod's container spec in place, because Kubernetes itself won't allow it no matter which admission controller is asking.

## One policy, two triggers

A single `ClusterPolicy` can carry both mechanisms at once, and in production it
usually does: an ordinary admission-time `mutate` rule so every *new* resource
arrives already correct, and a `mutateExistingOnPolicyUpdate` rule with a
`targets` block so the resources that were already there are brought into line
when the policy lands.

Once you have the RBAC grant in place from the checkpoint above, adding the
admission-time half is a second rule with no `targets` and no
`mutateExistingOnPolicyUpdate` — exactly the Part 1 shape. Create a fresh Pod
afterwards and it carries the same label the `legacy` Pods just acquired, with
the same final value.

The label ends up identical either way. What differs is what caused it: one path
runs because a request arrived, the other because a policy changed. Keeping those
two triggers distinct in your head is what stops "why did this Pod change when
nobody deployed anything?" from being a mystery.
