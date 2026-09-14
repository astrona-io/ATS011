# Part 1: generateExisting and Retroactive Creation

## One field, two very different policies

Here is Module 1's namespace rule, unchanged except for a single line:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: netpol-everywhere
spec:
  rules:
    - name: default-deny
      match:
        any:
          - resources:
              kinds:
                - Namespace
      exclude:
        any:
          - resources:
              namespaces:
                - kube-system
                - kube-public
                - kube-node-lease
                - kyverno
      generate:
        apiVersion: networking.k8s.io/v1
        kind: NetworkPolicy
        name: default-deny-ingress
        namespace: "{{request.object.metadata.name}}"
        synchronize: true
        generateExisting: true
        data:
          spec:
            podSelector: {}
            policyTypes:
              - Ingress
```

`generateExisting: true` changes the rule from "every namespace created from now on gets a `NetworkPolicy`" to "every namespace gets a `NetworkPolicy`, including the ones already here."

Without it, applying this policy to a cluster with fifty existing namespaces protects none of them, and the gap stays open until each namespace is somehow recreated — which for most namespaces is never.

> [!TIP]
> **Try it — a resource appears in a namespace nobody touched**
>
> ```sh
> kubectl get netpol -n legacy-a
> kubectl apply -f netpol-everywhere.yaml
> kubectl get netpol -n legacy-a
> kubectl get netpol -n legacy-b
> ```
>
> Expect something like:
>
> ```text
> No resources found in legacy-a namespace.
>
> clusterpolicy.kyverno.io/netpol-everywhere created
>
> NAME                   POD-SELECTOR   AGE
> default-deny-ingress   <none>         5s
>
> NAME                   POD-SELECTOR   AGE
> default-deny-ingress   <none>         5s
> ```
>
> The playground created `legacy-a` and `legacy-b` at startup, before any policy
> existed. Neither was created, updated, or touched in any way after you applied
> the policy — the trigger event was the *policy* appearing, not the namespace.
> Poll if the first read is empty; this is background work, not an admission
> response.

## The same asymmetry Section 030 found

It is worth naming what just happened, because the pattern recurs across Kyverno.

A rule has two possible evaluation paths: at **admission**, driven by a request, and in the **background**, driven by a controller on its own schedule. Validation exposes that choice as `spec.background`. Mutation exposes it as `mutateExistingOnPolicyUpdate`. Generation exposes it as `generateExisting`. Different field names, one idea — *does this rule also apply to what is already here?*

And in each case the background path is executed by a different controller with different permissions from the admission webhook. Section 040 met that directly: `mutateExistingOnPolicyUpdate` is refused at apply time unless the background controller holds `update` on the target kind. Generation has the same structure, which is why a generate rule that works for `NetworkPolicy` may fail for a kind the background controller has no rights over.

## Retroactive is a bigger decision than forward-looking

A forward-looking generate rule is easy to reason about: nothing that exists changes, and the first new namespace tells you whether the rule is right.

Turning on `generateExisting` makes the same policy act on the entire cluster the moment it is applied. For a default-deny `NetworkPolicy` that is not a neutral act — every namespace that previously had no ingress restrictions now has one, all at once, and workloads that depended on unrestricted ingress stop working together.

That is not an argument against the field. It is an argument for sequencing:

* Apply the rule **without** `generateExisting` first. New namespaces are protected, nothing existing changes, and you can see the generated resource is what you intended.
* Check what the retroactive pass *would* do. For a `NetworkPolicy`, that means knowing which namespaces currently rely on open ingress.
* Then turn `generateExisting` on, ideally narrowing `match` to a subset of namespaces first and widening once the first batch is fine.

The narrowing step is the one people skip. `match` accepts the same selectors it always has, so a label such as `netpol-rollout: wave-1` on a handful of namespaces makes the retroactive pass affect exactly those, and widening is a label change rather than a policy change.

> [!NOTE]
> `generateExisting` and `synchronize` answer different questions and are easy to conflate. `generateExisting` is about **the past**: does this rule reach resources that already exist? `synchronize` is about **the future**: once generated, is the downstream kept in step with its source, reverted when edited, and recreated when deleted? You can have either without the other. A one-time backfill that teams are then free to customise is `generateExisting: true` with `synchronize: false`; a strictly-maintained resource in new namespaces only is the reverse.

## Section recap

`generateExisting: true` makes a generate rule apply to resources that already exist, executed in the background rather than at admission — the generate-side counterpart of `spec.background` for validation and `mutateExistingOnPolicyUpdate` for mutation. Because it acts on the whole cluster the moment the policy lands, it deserves a staged rollout that a forward-looking rule does not. And it is independent of `synchronize`, which governs what happens to the downstream afterwards rather than which resources are reached in the first place.
