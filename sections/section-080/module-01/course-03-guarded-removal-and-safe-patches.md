# Part 3: Guarded Removal and Safe Patch Design

Part 2 ended on an uncomfortable asymmetry: three operations, three different answers to the same missing path, and only one of them loud. Before writing another patch, sit with how loud that one is.

> [!WARNING]
> This is a whole-request rejection by a `mutate` rule, and it applies to every Pod in the cluster that lacks that annotation — which, for a policy matching `kind: Pod` with no further narrowing, is likely to be almost all of them. A mistyped or unescaped pointer in a `replace` does not fail quietly for one resource; it can block Pod creation cluster-wide until you fix or delete the policy. Test a new `patchesJson6902` rule against a narrow `match` (a single namespace, a specific label) before widening it.

This part is about writing patches whose correctness does not depend on remembering which of the three answers you get.


## Making removal version-proof with preconditions

The table above is uncomfortable. `remove` happens to be lenient on v1.19.1 — but the difference between "lenient" and "rejects every Pod in your cluster" is one operation keyword, and leniency is behaviour you are observing rather than a contract you are relying on.

The robust pattern is to stop depending on it: gate the destructive rule behind a `preconditions` block that only lets it run when the field is actually there.

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: annotation-baseline
spec:
  rules:
    - name: add-required-annotation
      match:
        any:
          - resources:
              kinds:
                - Pod
      mutate:
        patchesJson6902: |-
          - op: add
            path: /metadata/annotations/policy.example.com~1reviewed
            value: "true"

    - name: remove-disallowed-annotation-if-present
      match:
        any:
          - resources:
              kinds:
                - Pod
      preconditions:
        all:
          - key: "{{ request.object.metadata.annotations.\"legacy/unmanaged-scanner\" || '' }}"
            operator: NotEquals
            value: ""
      mutate:
        patchesJson6902: |-
          - op: remove
            path: /metadata/annotations/legacy~1unmanaged-scanner
```

Two rules, deliberately asymmetric:

* **The `add` rule has no precondition.** It does not need one — `add` creates what is missing and overwrites what is present.
* **The `remove` rule does.** Now the operation only ever runs against a resource where the pointer is guaranteed to resolve, so it behaves identically whether the underlying implementation is lenient or strict. Swap `remove` for `replace` later and the rule still works.

The precondition key is worth decoding piece by piece:

```
{{ request.object.metadata.annotations."legacy/unmanaged-scanner" || '' }}
```

* **`request.object`** — the incoming resource as submitted, before this policy's mutations.
* **`."legacy/unmanaged-scanner"`** — the key is quoted because JMESPath, like the JSON Pointer, would otherwise read the `/` as syntax. Note that the escaping rule here is *different* from the pointer's: JMESPath wants double quotes, JSON Pointer wants `~1`. The same key is written two different ways in the same rule, and that is correct.
* **`|| ''`** — the fallback that makes this work at all. On a Pod with no `annotations` block, the left side resolves to nothing, and a bare unresolved variable causes a variable-substitution error rather than an empty string. `|| ''` turns "absent" into `""`.
* **`operator: NotEquals`, `value: ""`** — "the annotation resolved to something that isn't empty," which is the standard Kyverno idiom for "this key exists and has a value."

## A patch list is applied as a unit

One more property explains why a single bad operation is so disruptive, and it comes from RFC 6902 rather than from Kyverno: **a JSON Patch is atomic.** The operations in a list are applied in order, and if any one of them fails, the whole patch fails and none of it is applied.

```text
  incoming resource
        |
        v
   op 1  add      ok ------+
   op 2  replace  FAILS    |   whole patch discarded,
   op 3  remove   (never   |   admission request denied
                   reached)+
```

So a three-operation rule where only the second is wrong does not produce a partially-patched resource — it produces no patch at all, and under Kyverno's mutating webhook, no admitted resource either. That is the right behaviour: a half-applied patch would leave objects in states no one designed.

It also shapes how you debug one. The error names the policy, the rule, and the failing pointer, but not the operation's index in your list:

```text
mutation policy probe-replace error: failed to apply policy probe-replace rules
[unguarded-replace: failed to patch resource: replace operation does not apply:
doc is missing path: /metadata/annotations/legacy~1unmanaged-scanner: missing value]
```

`unguarded-replace` is the **rule** name. If that rule's `patchesJson6902` holds six operations, the pointer in the message is what identifies which one — another reason to keep patch lists short and rule names specific.


## Common pitfalls

> [!WARNING]
> **Writing the operation list as native YAML instead of a string.** `patchesJson6902` is a string field. Drop the `|-` block scalar and the resource fails schema validation at apply time.
>
> **Forgetting `~1` in an annotation or label pointer.** Silently addresses a structure that doesn't exist. With `add` you get a bizarre nested object; with `replace` or `remove` you get a path error or a no-op that looks like the rule never ran.
>
> **Assuming a JSON Pointer supports wildcards.** There is no `/spec/containers/*/image`. A pointer names one location. To touch every container you need `patchStrategicMerge` with the `(name)` anchor (Section 040), a `mutate.foreach` block, or one operation per index — and the last of those only works if you already know how many containers there are.
>
> **Reasoning about array indices without accounting for earlier operations.** Operations apply in order against a document that the previous operations already changed. An `add` that inserts at index 0 shifts every later index by one.

## Section recap

An unconditional `add` is safe by construction — it creates what is missing and overwrites what is present — so it needs no guard. Anything destructive should be gated behind a `preconditions` check that the target actually exists, which makes the rule behave identically whether the underlying operation is lenient or strict, and keeps it correct if someone later swaps `remove` for `replace`. Note that the same annotation key is spelled two different ways in such a rule: quoted for JMESPath in the precondition, `~1`-escaped for the JSON Pointer in the patch.
