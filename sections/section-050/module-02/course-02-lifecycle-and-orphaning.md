# Part 2: Lifecycle — Policy Deletion and Orphaning

## Deleting the policy deletes its work

Here is the question Module 1 left open. You have a generate rule producing a default-deny `NetworkPolicy` in fifty namespaces. Someone deletes the `ClusterPolicy`.

The intuitive answer is that the `NetworkPolicy` objects stay — they are ordinary Kubernetes resources, nobody deleted them, and removing a policy should stop *future* generation rather than undo past generation.

That is not what happens.

> [!TIP]
> **Try it — the downstream goes with the policy**
>
> ```sh
> kubectl get netpol -n legacy-a
> kubectl delete clusterpolicy netpol-everywhere
> kubectl get netpol -n legacy-a
> ```
>
> Expect something like:
>
> ```text
> NAME                   POD-SELECTOR   AGE
> default-deny-ingress   <none>         2m
>
> clusterpolicy.kyverno.io "netpol-everywhere" deleted
>
> No resources found in legacy-a namespace.
> ```
>
> Verified on v1.19.1: the generated `NetworkPolicy` was gone within a few
> seconds of the policy being deleted. Nobody deleted it directly, and nothing
> warned that deleting the policy would take it.

Sit with what that means for the example at hand. Deleting one `ClusterPolicy` removed the default-deny ingress rule from every namespace it had generated into — turning a cluster with baseline network isolation into one without, in a few seconds, as a side effect of an action that looked like it only affected policy.

This is the single most consequential thing to know about generate rules, and it is the opposite of the intuition most people bring.

## `orphanDownstreamOnPolicyDelete`

The field that changes it lives alongside `synchronize` in the `generate` block:

```yaml
generate:
  apiVersion: networking.k8s.io/v1
  kind: NetworkPolicy
  name: default-deny-ingress
  namespace: "{{request.object.metadata.name}}"
  synchronize: true
  generateExisting: true
  orphanDownstreamOnPolicyDelete: true
  data:
    spec:
      podSelector: {}
      policyTypes:
        - Ingress
```

Set to `true`, deleting the policy leaves the generated resources in place — orphaned, in the sense that nothing manages them any more, but present.

> [!TIP]
> **Try it — the same deletion, the opposite outcome**
>
> ```sh
> kubectl apply -f netpol-orphan.yaml
> kubectl get netpol -n legacy-a
> kubectl delete clusterpolicy netpol-orphan
> kubectl get netpol -n legacy-a
> ```
>
> Expect something like:
>
> ```text
> NAME                   POD-SELECTOR   AGE
> default-deny-ingress   <none>         31s
>
> clusterpolicy.kyverno.io "netpol-orphan" deleted
>
> NAME                   POD-SELECTOR   AGE
> default-deny-ingress   <none>         31s
> ```
>
> Same resource, same deletion, and this time it survives. Note the `AGE` did not
> reset — it is the same object, not a recreated one.

## Which behaviour do you want?

The default — delete the downstream with the policy — is correct for resources that only make sense as an extension of the policy. A generated `ConfigMap` holding policy-derived settings, or a `RoleBinding` that exists purely because a policy said so, should not outlive the rule that justified it. Leaving those behind produces resources nobody can explain a year later.

Orphaning is correct when the downstream provides **safety**, and its disappearance is worse than its being unmanaged. A default-deny `NetworkPolicy` is the clearest case: an unmanaged one that is slightly stale still denies traffic, while a deleted one denies nothing. The same reasoning covers generated `ResourceQuota`, `LimitRange`, and `PodDisruptionBudget` objects — anything whose absence is a weaker state than its presence.

The question to ask is: *if this resource stops being managed, is the cluster better off with it or without it?* Safety controls answer "with it" and want `orphanDownstreamOnPolicyDelete: true`. Conveniences answer "without it" and should take the default.

> [!NOTE]
> The mechanism here is **not** Kubernetes garbage collection. Module 1 established that a generated resource carries no `ownerReferences` — Kyverno tracks the trigger/source/downstream relationship through its own `generate.kyverno.io/*` labels and `UpdateRequest` objects. So this deletion is Kyverno actively removing resources it knows it created, not the API server collecting objects whose owner vanished. That is why the behaviour is configurable at all: an `ownerReference` relationship would give you no such switch.

## The other way a downstream disappears

Policy deletion is not the only path. With `synchronize: true`, a generated resource is also removed when its **trigger stops matching** the rule — for example a namespace relabelled so the rule's `match` no longer selects it.

That is the documented intent and it is consistent: `synchronize: true` means "this downstream is mine and I maintain it", and a resource whose reason for existing has gone away is no longer maintained into existence. Module 1 noted that this specific path is awkward to observe when the trigger is a Namespace and the downstream lives inside it, because deleting the namespace removes everything in it regardless — but a relabelled namespace that survives demonstrates it cleanly.

The practical consequence: with `synchronize: true`, the set of generated resources tracks the set of matching triggers in both directions. Widening `match` creates more; narrowing it destroys some. Editing the `match` block of a generate rule is a destructive operation on a scale that the edit itself does not look like.

> [!WARNING]
> **Common pitfalls**
>
> - **Assuming deleting a policy is a safe, reversible, policy-only action.** By default it deletes every resource that policy generated.
> - **Using the default for a safety control.** A default-deny `NetworkPolicy` that vanishes with its policy is an outage-shaped failure mode.
> - **Expecting `ownerReferences` to explain the relationship.** There are none; Kyverno tracks it with its own labels and `UpdateRequest` objects.
> - **Narrowing a generate rule's `match` casually.** Under `synchronize: true`, triggers that stop matching lose their downstream.
> - **Conflating `orphanDownstreamOnPolicyDelete` with `synchronize: false`.** The first governs what happens when the *policy* goes; the second governs whether the downstream is maintained while it stays.

## Section recap

Deleting a generate rule's policy deletes the resources it generated, verified on v1.19.1 and the opposite of most people's intuition. `orphanDownstreamOnPolicyDelete: true` reverses that, and is the right choice whenever the downstream is a safety control whose absence is worse than its being unmanaged. None of this runs through Kubernetes garbage collection — Kyverno tracks its own downstreams, which is precisely why the behaviour is a field you can set.
