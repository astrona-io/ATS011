# Part 2: Conditions, TTL Labels, and Deletion Semantics

## When match is not selective enough

`match` selects on the things Kubernetes indexes cheaply: kind, namespace, name, and labels. That covers a lot, but not everything you want to condition a deletion on. "Only Pods that have finished." "Only ConfigMaps whose `owner` annotation is empty." "Only Jobs owned by a particular controller." None of those is a label selector.

For that, `spec.conditions` takes the same `all`/`any` condition entries you wrote in Sections 020 and 070 — but against a different variable. In an admission rule, the resource under consideration is `request.object`. There is no admission request here, so a cleanup policy exposes the candidate resource as **`target`**:

```yaml
apiVersion: kyverno.io/v2
kind: ClusterCleanupPolicy
metadata:
  name: cleanup-by-condition
spec:
  match:
    any:
      - resources:
          kinds:
            - Pod
          namespaces:
            - cleanup-demo
  conditions:
    all:
      - key: "{{ target.metadata.labels.tier || '' }}"
        operator: Equals
        value: "scratch"
  schedule: "* * * * *"
```

`match` narrows to Pods in one namespace; `conditions` then narrows further to those whose `tier` label is `scratch`. (This particular example could have been a label selector — it is written as a condition so you can see the syntax on something easy to verify. The technique earns its keep on fields no selector can reach, like `target.status.phase`.)

The `|| ''` fallback is the same defensive idiom from Section 080: a Pod with no labels at all would otherwise leave the variable unresolved, and an unresolved variable is an evaluation error rather than an empty string.

> [!NOTE]
> `match` and `conditions` are not interchangeable, and the order they run in matters for cost. `match` is evaluated as a label/kind/namespace selector when the controller lists candidates from the API server; `conditions` are evaluated per-resource afterwards, in Kyverno. A policy whose `match` is `kinds: [Pod]` cluster-wide with a `conditions` block doing the real filtering works correctly, but makes the controller list and evaluate every Pod in the cluster on every tick. Put everything you can express in `match` into `match`.

Prove it with two Pods that `match` cannot tell apart — same kind, same
namespace, both selected — and only `conditions` distinguishes.

> [!TIP]
> **Try it — match selects both, conditions spares one**
>
> ```sh
> kubectl apply -f condition-policy.yaml
> kubectl run cond-yes -n cleanup-demo --image=nginx --restart=Never --labels=tier=scratch
> kubectl run cond-no  -n cleanup-demo --image=nginx --restart=Never --labels=tier=prod
> kubectl get pods -n cleanup-demo --show-labels
> ```
>
> Expect something like, immediately:
>
> ```text
> cond-no    1/1   Running   0   6s   tier=prod
> cond-yes   1/1   Running   0   6s   tier=scratch
> ```
>
> and after the next minute boundary:
>
> ```text
> cond-no   1/1   Running   0   71s
> ```
>
> `cond-yes` was swept. `cond-no` was matched, evaluated, and spared — the
> distinction was made per-resource by Kyverno, after the API server had already
> handed both of them over as candidates.

## The TTL label: cleanup without a policy

Sometimes you do not want a standing policy at all. You want *this one resource* to disappear after a while — a debug Pod, a temporary Secret, a preview namespace created by CI. Writing a `CleanupPolicy` per resource would be absurd.

Kyverno's cleanup controller also watches for a reserved label on any resource:

> [!TIP]
> **Try it — a self-deleting Pod, with no policy involved**
>
> ```sh
> kubectl get clustercleanuppolicy
> kubectl run ttl-pod -n cleanup-demo --image=nginx --restart=Never --labels='cleanup.kyverno.io/ttl=30s'
> kubectl get pod ttl-pod -n cleanup-demo
> ```
>
> Expect the Pod to exist, then be gone within a minute or so of the TTL
> expiring — while `kubectl get clustercleanuppolicy` shows no policy is
> responsible for it. (You still need the Pod RBAC grant from Part 1 in place;
> the next warning explains what happens if you do not.)

The value is either a duration (`30s`, `15m`, `2h`, `5d`) measured from the resource's creation timestamp, or an absolute RFC 3339 timestamp (`2026-09-14T15:30:00Z`). When the deadline passes, the controller deletes the resource on its next sweep.

TTL has its own sweep, separate from any policy's cron schedule — the controller's `ttlReconciliationInterval`, one minute by default. So the same "up to a minute late" caveat applies: a Pod created at `15:26:40` with `ttl=30s` becomes eligible at `15:27:10` and is actually deleted at the following reconciliation, not at `15:27:10` on the dot.

Because it is an ordinary label, you can add it to something that already exists:

```bash
kubectl label pod some-pod cleanup.kyverno.io/ttl=1h
```

The trade is expressiveness. A TTL label knows nothing about conditions, matches nothing, and applies only to the single object carrying it — but it needs no policy, no cron expression, and no thought about what else might match.

> [!WARNING]
> **The TTL label needs the same RBAC as a policy, and does not stop you when it is missing.** It is the same cleanup controller doing the deleting, so it still needs `delete` on that kind. Kyverno does notice — there is a `ttl-label` validating webhook that inspects the label at resource creation — but unlike the policy webhook it does not reject anything. Verified on Kyverno v1.19.1 with the aggregating `ClusterRole` removed: a Pod labelled `cleanup.kyverno.io/ttl=30s` is admitted normally, is never deleted, carries no error, emits no event, and the only trace is one line in the cleanup controller's log:
>
> ```
> INF ... doesn't have required permissions for deletion gvk="/v1, Kind=Pod"
>     logger=ttl-label/validate name=ttl-norbac namespace=cleanup-demo operation=CREATE
> ```
>
> A missing grant makes a *policy* fail loudly at apply time and a *TTL label* fail silently forever. If a TTL label "isn't working," check the grant before you check anything else:
>
> ```bash
> kubectl -n kyverno logs deploy/kyverno-cleanup-controller | grep 'required permissions'
> ```

## How the deletion is performed

`spec.deletionPropagationPolicy` controls what happens to a deleted resource's dependents. It takes the three standard Kubernetes values:

| Value | Behaviour |
| :--- | :--- |
| `Foreground` | Dependents are deleted first; the owner is removed only once they are gone. |
| `Background` | The owner is deleted immediately and the garbage collector removes dependents afterwards. |
| `Orphan` | The owner is deleted and its dependents are left behind, ownerless. |

This matters most when you clean up something that owns other things — deleting a `Job` with `Orphan` leaves its Pods running forever, which is occasionally what you want and usually a bug. When the field is omitted, the API server's own default applies; set it explicitly whenever you clean up a kind that owns dependents.

Everything else about the deletion is ordinary. Kyverno issues a normal delete: graceful termination periods are honoured, finalizers still run, and owner references still work. You can see it in the event stream as a plain `Killing` event, indistinguishable from `kubectl delete`.

## Where `DeletingPolicy` fits

Every `CleanupPolicy` you apply on v1.19.1 answers with:

```
Warning: kyverno.io/v2 ClusterCleanupPolicy is deprecated and will be removed in a future
release; migrate to DeletingPolicy (policies.kyverno.io)
```

`DeletingPolicy` and `NamespacedDeletingPolicy` are part of the newer `policies.kyverno.io` API group — the same family as `ValidatingPolicy` and `MutatingPolicy` that Section 110 covers. They do the same job with CEL expressions in place of JMESPath `conditions`, aligning cleanup with the direction the rest of Kyverno is moving.

Two practical points. First: the deprecation is a signpost, not a removal — `CleanupPolicy` and `ClusterCleanupPolicy` are fully functional on this version, and they are what the KCA Writing Policies domain asks you to author. Do not let the warning talk you out of learning them. Second: the concepts transfer almost completely. A `DeletingPolicy` still schedules with cron, still selects resources, still needs the cleanup controller to hold delete permission on the kind. What changes is the expression language, not the model.

## Common pitfalls

> [!WARNING]
> **Expecting immediate deletion.** A cleanup policy is a periodic sweep on a cron boundary, not a trigger. Even `* * * * *` means "up to a minute late." If you need something gone the instant it becomes eligible, a cleanup policy is the wrong tool.
>
> **Using `request.object` in `conditions`.** There is no admission request during a sweep. The candidate resource is `target`, and a condition written against `request.object` has nothing to resolve.
>
> **Granting RBAC with the kind name instead of the resource name.** A `ClusterRole` rule takes `resources: ["pods"]` — plural and lowercase — not `Pod`. Getting this wrong produces the same `no permission to delete kind Pod` error as granting nothing.
>
> **Assuming a namespaced `CleanupPolicy` can reach outside its namespace.** It cannot, regardless of what its `match` block says. Cluster-wide sweeps need `ClusterCleanupPolicy`.

## Section recap

`conditions` filters candidates that `match` could not, using the same operator syntax you already know against the `target` variable. The `cleanup.kyverno.io/ttl` label handles the one-off case without a policy, at the cost of expressiveness and with a silent failure mode when RBAC is missing. `deletionPropagationPolicy` decides what happens to dependents. And the deprecation warning pointing at `DeletingPolicy` describes where the API is going, not a reason to avoid the policy type the exam asks about.
