# Part 1: cloneList: Cloning Many Sources

## The limit of clone

Module 1's `generate.clone` names one source object by `namespace` and `name`. To share three objects you would need three rules, and a fourth source object means editing the policy.

`generate.cloneList` flips the question. Instead of naming each object, you name a source **namespace**, a list of **kinds**, and optionally a **label selector**. Kyverno clones every matching object it finds there.

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: share-config
spec:
  rules:
    - name: clone-shared
      match:
        any:
          - resources:
              kinds:
                - Namespace
              selector:
                matchLabels:
                  needs-shared: "true"
      generate:
        namespace: "{{ request.object.metadata.name }}"
        synchronize: true
        cloneList:
          namespace: shared-config
          kinds:
            - v1/ConfigMap
            - v1/Secret
          selector:
            matchLabels:
              share: "true"
```

Three things to notice.

* `generate.namespace` is the **destination**: the new namespace. `cloneList.namespace` is the **source**. They are two different fields with the same name.
* `kinds` entries are written `group/version/Kind`. Core resources have no group, so ConfigMap is `v1/ConfigMap`. A Deployment would be `apps/v1/Deployment`.
* There is no `kind`, `name` or `apiVersion` directly under `generate`. The list replaces them.

## What the selector decides

The `selector` is optional and limits which source objects are cloned. With the rule above, a ConfigMap in `shared-config` is copied only when it carries the label `share: "true"`. Without a selector, **every** object of the listed kinds in the source namespace is copied.

That makes the label an opt-in. Anyone who puts an object in the source namespace decides, by labelling it, whether it spreads to every new namespace. An unlabelled ConfigMap stays private. Leaving the selector out turns the source namespace into a broadcast channel, so treat that as a deliberate choice.

> [!TIP]
> **Try it — clone two of three ConfigMaps**
>
> <!-- astrona:playground:renew -->
> Save the policy above as `share-config.yaml`, then:
>
> ```sh
> kubectl apply -f share-config.yaml
> kubectl create namespace team-x --dry-run=client -o yaml | kubectl label --local -f - needs-shared=true -o yaml | kubectl apply -f -
> kubectl get configmap,secret -n team-x
> ```
>
> After a few seconds `team-x` contains `app-settings`, `feature-flags` and `registry-auth`, but not `private-notes`, because that one has no `share` label. Poll if the first read is empty: generation is processed by the background controller, not in the admission response.

## Synchronize and the source

With `synchronize: true`, the copies follow their sources. Edit `app-settings` in `shared-config` and the copy in `team-x` is updated. Delete the source and its copies are deleted too. Kyverno marks the source objects with its own labels to track this, so no other controller may strip those labels.

The background controller needs RBAC on each kind in the list. The playground grants it for ConfigMaps and Secrets. A kind with no grant makes the policy fail at apply time, the same rule Module 1 taught for single clones.

## Common pitfalls

> [!WARNING]
> - **Confusing the two `namespace` fields.** `generate.namespace` is where copies go. `cloneList.namespace` is where they come from.
> - **Omitting the selector by accident.** Every object of the listed kinds is cloned, including ones never meant to be shared.
> - **Writing a kind as `ConfigMap` or `configmap`.** Use `v1/ConfigMap`.
> - **Forgetting RBAC for a kind.** The background controller must be able to read the source and create the copy.
> - **Mixing `clone`, `cloneList` and `data` in one generate block.** Use one of them per rule.
