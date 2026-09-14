# Part 1: configMap and variable

## Policy data that changes more often than the policy

A registry allowlist is a list of strings. Written into the policy, every change to that list is a change to a `ClusterPolicy` — reviewed, approved, and applied by whoever owns cluster policy, for what is really an operational edit.

A `configMap` context entry moves the list out:

```yaml
context:
  - name: allowed
    configMap:
      name: allowed-registries
      namespace: policy-config
```

Kyverno reads that ConfigMap during admission and binds the whole object to `allowed`. Its keys are then reachable under `allowed.data`, exactly as they are on the ConfigMap itself:

```yaml
validate:
  message: >-
    Images must come from one of: {{ allowed.data.registries }}.
    Got {{ request.object.spec.containers[0].image }}.
  deny:
    conditions:
      all:
        - key: "{{ request.object.spec.containers[0].image }}"
          operator: NotEquals
          value: "ghcr.io/*"
```

The ConfigMap holding `registries: ghcr.io,registry.k8s.io` is ordinary:

```bash
kubectl create ns policy-config
kubectl create configmap allowed-registries -n policy-config \
  --from-literal=registries='ghcr.io,registry.k8s.io'
```

> [!TIP]
> **Try it — the message quotes data the policy does not contain**
>
> ```sh
> kubectl apply -f registry-from-configmap.yaml
> kubectl run cm-bad --image=nginx:1.27 --restart=Never
> kubectl run cm-ok --image=ghcr.io/kyverno/test-verify-image:signed --restart=Never
> ```
>
> Expect something like:
>
> ```text
> registry-from-configmap:
>   image-registry-allowlist: 'Images must come from one of: ghcr.io,registry.k8s.io. Got nginx:1.27.'
>
> pod/cm-ok created
> ```
>
> The list in that message is not in the policy — it came from the ConfigMap,
> read during this request. Edit the ConfigMap and the next rejection quotes the
> new value, with no policy change at all.

The playground seeds this ConfigMap for you, so the checkpoint works immediately. On a real cluster, note that the Kyverno admission controller needs read access to the ConfigMap's namespace — the stock install's `view` binding covers ConfigMaps, which is why this works without extra RBAC, exactly as Module 1 found for Pods.

> [!WARNING]
> **A `configMap` entry that cannot be read does not fail loudly.** If the ConfigMap is missing, misnamed, or in a namespace Kyverno cannot read, the variable resolves to nothing — and what happens next depends on how you used it. Referenced in a `message`, you get an empty string in the error. Referenced in a condition, you get a variable-resolution failure that behaves like any other rule error. Neither says "your ConfigMap is missing". If a data-driven rule starts behaving strangely, confirm the ConfigMap exists and is readable before suspecting the rule.

## Keeping the data and the logic honest

Externalising data is genuinely useful and has one sharp edge worth stating: **the ConfigMap becomes part of your policy's trust boundary.** Anyone who can edit `allowed-registries` can effectively rewrite what the rule enforces, without touching a policy object or appearing in a policy review.

That is a reason to be deliberate about which namespace holds policy data, and to treat RBAC on it as policy RBAC. A dedicated namespace such as `policy-config`, writable only by the team that owns the policies, keeps the delegation intentional. Putting the ConfigMap in an application namespace hands the application team a way to edit the rule that governs them.

## The `variable` entry type

The other context type is the simplest and easy to overlook: `variable` computes a value and gives it a name.

```yaml
context:
  - name: imageData
    imageRegistry:
      reference: "{{ request.object.spec.containers[0].image }}"
  - name: summary
    variable:
      jmesPath: "[imageData.registry, imageData.repository, imageData.resolvedImage]"
```

Two things it is for.

**Naming an intermediate result.** A JMESPath expression repeated in three conditions is three places to update and three chances to make them disagree. Bound once as a `variable`, it has a name, and the conditions read as statements about that name rather than as re-derivations.

**Making a value usable where the raw path is not.** This one is a practical finding rather than a design intent. Referencing a nested field of another context entry directly inside a `message` — `{{ imageData.configData.os }}` — came back as an empty string when tested on Kyverno v1.19.1, while the *same* path used in a `deny` condition resolved correctly. Binding it through a `variable` entry first and referencing that name in the message produced the value. If a message renders blank where a condition on the same path works, that indirection is the fix.

A `variable` entry also accepts a literal `value` and a `default`, which is the tidier way to express a constant a policy refers to repeatedly.

## Context entries are ordered

Context entries are evaluated **in the order they are written**, and each one can reference the ones above it. That is what makes the example above work: `summary` reads `imageData` because `imageData` is defined first.

The consequence is that reordering a `context` block is not cosmetic. Moving an entry above something it depends on leaves the dependency unresolved at the moment it is needed. There is no dependency graph being computed — the list is evaluated top to bottom, once, before the rule body runs.

That also means every context entry is fetched on **every matching admission request**, whether the rule body ends up needing it or not. A rule with four context entries makes four lookups per request. Section 020's `preconditions` are evaluated after context, so they do not save you the fetch; narrowing `match` does.

> [!WARNING]
> **Common pitfalls**
>
> - **Forgetting `.data`.** A `configMap` entry binds the whole ConfigMap object. The keys are under `<name>.data`, not directly under `<name>`.
> - **Putting policy data in an application namespace.** Whoever can edit the ConfigMap can rewrite the rule.
> - **Assuming a missing ConfigMap produces a clear error.** It produces an empty value or a resolution failure, neither of which names the ConfigMap.
> - **Reordering context entries.** They are evaluated top to bottom and later entries reference earlier ones.
> - **Adding context entries "just in case".** Each one is a lookup on every matching request.

## Section recap

A `configMap` entry externalises policy data so operational changes stop being policy changes — at the cost of extending the policy's trust boundary to whoever can edit that ConfigMap. A `variable` entry names an intermediate value, which keeps repeated expressions in one place and, on this version, is what makes a nested context field usable inside a `message`. Context entries evaluate in written order, each may reference its predecessors, and all of them run on every matching request.
