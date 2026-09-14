# Part 1: Schedules, Matching, and the RBAC Requirement

## Two kinds, one shape

Cleanup comes in the same scoped pair as `Policy`/`ClusterPolicy`:

| Kind | Scope | Can delete |
| :--- | :--- | :--- |
| `CleanupPolicy` | namespaced | resources in its own namespace only |
| `ClusterCleanupPolicy` | cluster-wide | anything its `match` selects, in any namespace |

Both live in the `kyverno.io/v2` API group on Kyverno v1.19.1. Here is a complete `ClusterCleanupPolicy` — this is the entire resource, not an excerpt:

```yaml
apiVersion: kyverno.io/v2
kind: ClusterCleanupPolicy
metadata:
  name: cleanup-ephemeral-pods
spec:
  match:
    any:
      - resources:
          kinds:
            - Pod
          selector:
            matchLabels:
              lifecycle: ephemeral
  schedule: "* * * * *"
```

Notice what is *absent*. There is no `rules` array — the policy itself is the rule. There is no `validate`, `mutate`, or `generate` block, because the action is always the same one: delete. There is no `validationFailureAction`, because nothing is being admitted or rejected. A cleanup policy has exactly two required parts: a `match` that says *what*, and a `schedule` that says *when*.

The `match` block is the one you already know from Section 010 — `any`/`all`, `resources.kinds`, `namespaces`, `names`, `selector` for label matching — and `exclude` works the same way alongside it.

## The schedule is a cron expression, and it means what cron means

`schedule` is a standard five-field cron expression: minute, hour, day-of-month, month, day-of-week.

| Expression | Fires |
| :--- | :--- |
| `* * * * *` | every minute |
| `*/5 * * * *` | every five minutes |
| `0 * * * *` | on the hour |
| `0 3 * * *` | at 03:00 daily |
| `0 3 * * 0` | at 03:00 on Sundays |

This has a consequence people consistently get wrong: **a cleanup policy is not a deletion trigger, it is a periodic sweep.** A Pod that becomes eligible one second after a tick sits there until the next tick. With `* * * * *` that is up to a minute; with `0 3 * * *` it is up to a day. Nothing about a cleanup policy is immediate, and no schedule expression makes it so — one minute is the finest granularity cron offers.

You can see the sweep happening on the policy's status:

```bash
kubectl get clustercleanuppolicy cleanup-ephemeral-pods -o jsonpath='{.status}'
# {"lastExecutionTime":"2026-09-14T15:25:00Z"}
```

Note the timestamp: `15:25:00`, exactly on the minute boundary. Ticks land on cron boundaries, not on "one minute after you applied the policy."

## The RBAC requirement, and the error that teaches it

Apply that policy on the playground — which deliberately ships with no cleanup
permissions — and it does not get created at all.

> [!TIP]
> **Try it — refused before it can delete anything**
>
> ```sh
> kubectl apply -f cleanup-policy.yaml
> ```
>
> Expect something like:
>
> ```text
> Warning: kyverno.io/v2 ClusterCleanupPolicy is deprecated and will be removed in a future release; migrate to DeletingPolicy (policies.kyverno.io), see https://kyverno.io/docs/guides/migration-to-cel/
> Error from server: error when creating "cleanup-policy.yaml": admission webhook "kyverno-cleanup-controller.kyverno.svc" denied the request: cleanup controller has no permission to delete kind Pod
> ```
>
> Two separate things in one response, and it is worth keeping them apart: a
> deprecation warning about the API's future, and a hard refusal about
> permissions right now. Only the second one stopped anything.

Two separate things happened there, and it is worth keeping them apart.

The **warning** is about API evolution, not about your policy being wrong — Kyverno v1.19.1 is signposting the newer CEL-based `DeletingPolicy` type that Part 2 comes back to. Like the `ClusterPolicy` deprecation warning you have been seeing since Section 010, it is expected and safe to ignore; `CleanupPolicy` is what the KCA asks about.

The **error** is the real content of this section. Kyverno's cleanup controller runs under its own ServiceAccount, and that account's aggregated `ClusterRole` grants it very little: it can read namespaces and ConfigMaps, manage its own CRDs and reports, and create `SubjectAccessReview` objects — and that is roughly it. It cannot delete Pods, Jobs, ConfigMaps, or anything else you are likely to want cleaned up.

This is a deliberate design choice, and a good one. A controller that could delete anything in the cluster on a schedule is a controller that can destroy the cluster on a schedule. So Kyverno ships it deliberately powerless and makes you opt in, one kind at a time.

What makes the experience bearable is *when* you find out. Kyverno's cleanup webhook performs a `SubjectAccessReview` against its own ServiceAccount at the moment you apply the policy, and refuses the policy if the answer is no. You get a precise error at apply time — naming the exact kind — rather than a policy that sits there looking healthy while silently deleting nothing.

> [!NOTE]
> Reading the error as a *Kyverno* permission problem sends people looking at their own kubeconfig and their own RBAC. It is not about you. `cleanup controller has no permission` means the `kyverno-cleanup-controller` ServiceAccount lacks the permission, regardless of how privileged the user applying the policy is. A cluster-admin applying this policy gets the identical error.

## Granting the permission

Kyverno's cleanup `ClusterRole` is an **aggregated** role. Aggregation is a Kubernetes RBAC feature: a `ClusterRole` can declare an `aggregationRule` with label selectors, and the API server continuously merges in the rules of every other `ClusterRole` carrying those labels. You never edit Kyverno's role — you create your own and label it so it gets absorbed.

> [!TIP]
> **Try it — read the label Kyverno is watching for**
>
> ```sh
> kubectl get clusterrole kyverno:cleanup-controller -o jsonpath='{.aggregationRule}'
> ```
>
> Expect something like:
>
> ```text
> {"clusterRoleSelectors":[{"matchLabels":{"rbac.kyverno.io/aggregate-to-cleanup-controller":"true"}}, ...]}
> ```
>
> That label is the entire interface. Any `ClusterRole` carrying it gets its
> rules folded into Kyverno's cleanup role by Kubernetes itself — you never edit
> Kyverno's role directly.

So the grant is a small `ClusterRole` carrying `rbac.kyverno.io/aggregate-to-cleanup-controller: "true"`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kyverno:cleanup-pods
  labels:
    rbac.kyverno.io/aggregate-to-cleanup-controller: "true"
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch", "delete"]
```

`delete` is the operative verb, but `list` and `watch` matter too — the controller has to *find* the resources before it can delete them, and `get` is needed to evaluate conditions against them. Granting `delete` alone will not work.

Note the plural, lowercase, API-plumbing name: RBAC `resources` are `pods`, not `Pod`. The `match` block in your cleanup policy uses the Kubernetes *kind* (`Pod`); the `ClusterRole` uses the *resource* name (`pods`). Mixing these up is a common first failure, and it produces exactly the same `no permission to delete kind Pod` error as granting nothing at all.

> [!WARNING]
> Scope the grant to the kinds you actually intend to clean up. `resources: ["*"]` with `verbs: ["delete"]` on an aggregating label hands a scheduled controller the ability to delete every object in the cluster, and a single over-broad `match` block then becomes a cluster-wide outage rather than a policy bug. Grant `pods`, or `jobs`, or `configmaps` — one line per kind you need.

## Putting it together: one victim, one survivor

With the grant applied, the same policy that was refused a moment ago is
accepted. Then create two Pods that differ in exactly one label and wait for a
minute boundary — the waiting is not incidental, it is the mechanism.

> [!TIP]
> **Try it — a sweep that discriminates**
>
> ```sh
> kubectl apply -f cleanup-rbac.yaml
> kubectl apply -f cleanup-policy.yaml
> kubectl get clustercleanuppolicy
>
> kubectl create ns cleanup-demo
> kubectl run doomed -n cleanup-demo --image=nginx --restart=Never --labels=lifecycle=ephemeral
> kubectl run keeper -n cleanup-demo --image=nginx --restart=Never --labels=lifecycle=permanent
> kubectl get pods -n cleanup-demo --show-labels
> ```
>
> Expect something like:
>
> ```text
> clusterrole.rbac.authorization.k8s.io/kyverno:cleanup-pods created
> clustercleanuppolicy.kyverno.io/cleanup-ephemeral-pods created
>
> NAME                     SCHEDULE    AGE
> cleanup-ephemeral-pods   * * * * *   0s
>
> NAME     READY   STATUS    RESTARTS   AGE   LABELS
> doomed   1/1     Running   0          8s    lifecycle=ephemeral
> keeper   1/1     Running   0          8s    lifecycle=permanent
> ```
>
> If the policy is still refused, give RBAC aggregation a few seconds and apply
> again — the API server has to fold your `ClusterRole` in before Kyverno's
> permission check can see it.

Now wait for the next minute boundary and look again. This is the part that feels
wrong the first time: nothing happens immediately, because a cleanup policy is a
scheduled sweep rather than a trigger.

```bash
kubectl get pods -n cleanup-demo
# NAME     READY   STATUS    RESTARTS   AGE
# keeper   1/1     Running   0          71s

kubectl get clustercleanuppolicy cleanup-ephemeral-pods -o jsonpath='{.status}'
# {"lastExecutionTime":"2026-09-14T15:25:00Z"}
```

`doomed` is gone, `keeper` is untouched, and the execution timestamp ends in
`:00` — ticks land on cron boundaries, not one minute after you applied the
policy. The deletion itself is completely ordinary; the event stream shows a
plain `Killing` event, indistinguishable from `kubectl delete`.

## Section recap

A cleanup policy is a cron schedule plus a `match` block, executed by a separate controller that holds no deletion rights until you grant them with a labelled, aggregating `ClusterRole`. Kyverno checks that grant at apply time and refuses the policy with `cleanup controller has no permission to delete kind <Kind>` if it is missing. Deletion happens on cron boundaries, so "within a minute" is the tightest timing any schedule can promise.
