# Part 1: MutatingPolicy and GeneratingPolicy

## One kind per job

A classic `ClusterPolicy` is a container. Inside it, `spec.rules[]` can hold a validate rule, a mutate rule, a generate rule, and a verifyImages rule, all governing different resources, all in one object.

The `policies.kyverno.io` family does not work that way. Each rule type became its own **kind**:

```text
              ClusterPolicy                    policies.kyverno.io
              -------------                    -------------------
  rules[].validate        ------------------>  ValidatingPolicy
  rules[].mutate          ------------------>  MutatingPolicy
  rules[].generate        ------------------>  GeneratingPolicy
  rules[].verifyImages    ------------------>  ImageValidatingPolicy
  ClusterCleanupPolicy    ------------------>  DeletingPolicy
```

Each also has a `Namespaced*` counterpart — `NamespacedMutatingPolicy` and so on — replacing the `ClusterPolicy`/`Policy` scoping pair with a naming convention instead of a shared spec.

The gain is that each kind's schema describes exactly one job, so there is no `spec` field that only applies when you are doing one of five things. The cost is that a requirement spanning two rule types now spans two objects: "default this label, then require it" was one `ClusterPolicy` with two rules and is now a `MutatingPolicy` and a `ValidatingPolicy` that have to be applied, reviewed, and deleted together.

## MutatingPolicy

```yaml
apiVersion: policies.kyverno.io/v1
kind: MutatingPolicy
metadata:
  name: add-managed-by
spec:
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE"]
        resources: ["pods"]
  mutations:
    - patchType: ApplyConfiguration
      applyConfiguration:
        expression: >
          Object{ metadata: Object.metadata{ labels: {"managed-by": "kyverno-mutatingpolicy"} } }
```

`matchConstraints` is identical to `ValidatingPolicy`'s — same lowercase plural resource names, same explicit `operations`. What changes is the body: `validations` becomes `mutations`, and each mutation declares a `patchType`.

Two patch types are available, and they map onto shapes you already know:

| `patchType` | Body field | Closest classic equivalent |
| :--- | :--- | :--- |
| `ApplyConfiguration` | `applyConfiguration.expression` | `patchStrategicMerge` (Section 040) |
| `JSONPatch` | `jsonPatch.expression` | `patchesJson6902` (Section 080) |

The `ApplyConfiguration` expression is the unfamiliar part. It is CEL **object initialization** — you construct the fragment you want merged, rather than writing it as YAML:

```text
  Object{ metadata: Object.metadata{ labels: {"managed-by": "..."} } }
  ^^^^^^          ^^^^^^^^^^^^^^^^
  the resource     the typed sub-object at that path
```

`Object` is the root of the resource being mutated, and `Object.metadata` is its `metadata` sub-object. Nesting them mirrors the path you are patching. Read the expression above as the CEL spelling of the strategic-merge fragment `metadata: {labels: {managed-by: ...}}`.

> [!TIP]
> **Try it — a mutation with no YAML fragment in sight**
>
> ```sh
> kubectl apply -f mutating-policy.yaml
> kubectl get mutatingpolicy
> kubectl run mp-test --image=nginx:1.27 --restart=Never
> kubectl get pod mp-test -o jsonpath='{.metadata.labels}'
> ```
>
> Expect something like:
>
> ```text
> mutatingpolicy.policies.kyverno.io/add-managed-by created
>
> NAME             AGE   READY
> add-managed-by   41s   true
>
> pod/mp-test created
> {"managed-by":"kyverno-mutatingpolicy","run":"mp-test"}
> ```
>
> The label was added by an expression, not by a YAML fragment. As with every
> policy in this family, wait for `READY: true` before submitting anything —
> the object is accepted by the API server before Kyverno has compiled it.

`spec` also carries `reinvocationPolicy`, which is the API server's own mechanism for re-running a mutating webhook after other webhooks have made their changes. That matters here for exactly the reason Section 040's Module 2 covered at length: a mutation that is not idempotent and gets re-invoked compounds.

> [!NOTE]
> Applying this policy as `policies.kyverno.io/v1alpha1` produces `Warning: policies.kyverno.io/v1alpha1 MutatingPolicy is deprecated; use policies.kyverno.io/v1`. The replacement family is itself still versioning — so material written a few releases ago may show an `apiVersion` that now warns, exactly as `kyverno.io/v1 ClusterPolicy` does. Check the version your cluster serves rather than copying an `apiVersion` from a blog post.

## GeneratingPolicy

`GeneratingPolicy` replaces `rules[].generate`, and its body is a `generate` list where each entry supplies either an `expression` or a `template`:

```yaml
apiVersion: policies.kyverno.io/v1
kind: GeneratingPolicy
metadata:
  name: default-netpol
spec:
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE"]
        resources: ["namespaces"]
  generate:
    - expression: >
        [ ... CEL constructing the downstream resource ... ]
```

The split between `expression` and `template` mirrors Section 050's split between computing a resource and declaring one: an expression builds the downstream object in CEL, a template declares it much as `generate.data` did.

`spec` also offers `useServerSideApply`, which changes how the generated resource is written — relevant when several controllers touch the same object and you want field ownership tracked rather than the whole object replaced.

> [!NOTE]
> This module verified `MutatingPolicy` and `DeletingPolicy` end to end on a live v1.19.1 cluster. `GeneratingPolicy` is described here from its resource schema — the field names, their types, and which are required are accurate, but there is no captured transcript of one generating a resource. Treat the shape as reliable and the runtime behaviour as something to confirm on your own cluster before depending on it.

## What the split costs

Section 000 Part 3 established the ordering guarantee: every mutate rule on the cluster runs before any validate rule. That guarantee is about **rule types**, not about policy objects, so it holds across this family too — a `MutatingPolicy` still runs before a `ValidatingPolicy`.

What you lose is *co-location*. In a classic `ClusterPolicy`, a mutate rule that supplies a default and a validate rule that requires it sit in one object, are reviewed as one change, and are deleted together. Split across two kinds, nothing binds them: deleting the `MutatingPolicy` leaves the `ValidatingPolicy` rejecting every resource the mutation used to fix, and no tooling will warn you.

That is not an argument against the new family. It is an argument for naming and labelling paired policies so the relationship is visible to whoever deletes one of them.

## Section recap

The `policies.kyverno.io` family gives each classic rule type its own kind, with `Namespaced*` counterparts replacing the `Policy`/`ClusterPolicy` pair. `MutatingPolicy` swaps `validations` for `mutations`, each declaring a `patchType` of `ApplyConfiguration` (CEL object initialization, the strategic-merge analogue) or `JSONPatch` (the RFC 6902 analogue). `GeneratingPolicy` takes a `generate` list of expressions or templates. The rule-type ordering guarantee survives the split; what does not survive is having related rules in one reviewable object.
