# Section 080 Knowledge Check: JSON Patches

Test your diagnostic reasoning before attempting the lab. Try to answer each question yourself before expanding the explanation.

---

**1.** You need a `mutate` rule that deletes an annotation from incoming Pods. Why is `patchStrategicMerge` a poor fit, and what does `patchesJson6902` offer instead?

<details>
<summary>Show Answer</summary>

`patchStrategicMerge` describes the shape you want the resource to have, and there is no natural way to describe the *absence* of a key — writing the key with an empty value sets it to empty rather than deleting it. (Strategic merge does have a `$patch: delete` directive, but it is awkward and context-limited.) `patchesJson6902` is an ordered list of RFC 6902 operations, one of which is literally `op: remove` aimed at an exact JSON Pointer path. Deletion, index-based array targeting, and list appending are the three jobs that push you from strategic merge to JSON Patch.
</details>

---

**2.** What does the path `/spec/containers/0/env/-` address, and what happens if the first container has no `env` array at all?

<details>
<summary>Show Answer</summary>

It addresses the position one past the end of the first container's `env` array — RFC 6902's append token, written as a bare `-` where an index would go. If `env` does not exist, a strict reading of RFC 6902 would expect failure, since the parent of the target must exist. Verified on Kyverno v1.19.1, it does not fail: the `env` array is created with your value as its only element. That leniency is what lets one `add` operation cover both the has-env and no-env Pod shapes, but treat it as observed behaviour on this version rather than a portable guarantee.
</details>

---

**3.** Your rule targets the annotation `policy.example.com/reviewed` with the path `/metadata/annotations/policy.example.com/reviewed`. What is wrong with it?

<details>
<summary>Show Answer</summary>

The `/` inside the key name is being read as a JSON Pointer path separator, so the pointer resolves as four segments and asks for a `reviewed` key nested inside an object stored under `policy.example.com` — a structure that does not exist. RFC 6901 requires a literal `/` in a key to be escaped as `~1` (and a literal `~` as `~0`). The correct path is `/metadata/annotations/policy.example.com~1reviewed`. Nothing else needs escaping — dots, dashes, and colons are ordinary characters in a pointer.
</details>

---

**4.** A rule does `op: add` on `/metadata/annotations/policy.example.com~1reviewed` with value `"true"`. A Pod arrives that already has that annotation set to `"false"`. What happens, and does the rule need a precondition to be safe?

<details>
<summary>Show Answer</summary>

The value is overwritten with `"true"`, and the request is admitted. RFC 6902 defines `add` against an object member that already exists as a replacement, not an error — and it also creates the parent map if `annotations` is absent entirely. Because `add` handles both "missing" and "already present," an unconditional `add` is safe to run on every resource and needs no precondition.
</details>

---

**5.** Two rules, identical except for the operation: one does `op: remove` on an annotation path, the other does `op: replace` on the same path. A Pod arrives that does not have the annotation. What happens in each case on Kyverno v1.19.1?

<details>
<summary>Show Answer</summary>

`remove` is a silent no-op — the Pod is admitted, nothing errors. `replace` rejects the entire admission request with `mutate.kyverno.svc-fail denied the request: ... failed to patch resource: replace operation does not apply: doc is missing path: <pointer>: missing value`. The two operations do not share a policy on missing paths, which is exactly why you should not write a destructive rule that depends on knowing which behaviour you get.
</details>

---

**6.** You apply a cluster-wide `mutate` rule doing an unguarded `op: replace` against a path most Pods do not have. What is the blast radius, and what should you have done first?

<details>
<summary>Show Answer</summary>

Every Pod creation in the cluster that lacks that path is rejected by the mutation webhook — not one resource failing quietly, but Pod admission broken cluster-wide until you fix or delete the policy. Because the rule matched `kind: Pod` with nothing narrowing it, that is likely to be nearly every Pod. Test any new `patchesJson6902` rule against a narrow `match` (one namespace, or a specific label) and widen it only once you have proven the pointer resolves on the resources you expect.
</details>

---

**7.** A guarded-removal rule uses this precondition key: `{{ request.object.metadata.annotations."legacy/unmanaged-scanner" || '' }}`. Why the double quotes, why the `|| ''`, and why does the same key appear escaped as `legacy~1unmanaged-scanner` elsewhere in the same rule?

<details>
<summary>Show Answer</summary>

The double quotes are JMESPath's way of quoting a key containing a `/`, which JMESPath would otherwise try to read as syntax. The `|| ''` supplies an empty-string fallback: on a Pod with no `annotations` block at all, the left side resolves to nothing and a bare unresolved variable produces a variable-substitution error rather than an empty value — the fallback turns "absent" into `""` so the `NotEquals ""` comparison works as an existence check. The two different spellings are correct and not a mistake: the precondition is JMESPath (double-quote the key) and the patch path is an RFC 6901 JSON Pointer (escape `/` as `~1`). Same key, two syntaxes, one rule.
</details>

---

**8.** Can a single JSON Pointer path apply an operation to every container in a Pod — for example `/spec/containers/*/image`?

<details>
<summary>Show Answer</summary>

No. A JSON Pointer is a literal walk to exactly one location; it has no wildcards, filters, or expressions of any kind. To affect every container you need `patchStrategicMerge` with the `(name)` anchor (Section 040), a `mutate.foreach` block, or one explicit operation per index — and the last only works if you already know the container count, which at admission time you generally do not.
</details>

---

**9.** A patch list contains an `add` that inserts a new element at `/spec/containers/0`, followed by a second operation targeting `/spec/containers/1`. Which container does the second operation hit?

<details>
<summary>Show Answer</summary>

The container that was originally at index 0 — because the first operation inserted *before* index 0 and shifted everything down by one. RFC 6902 operations apply in order against a document already modified by the preceding operations, so array indices are positions at that moment in the patch, not positions in the resource as submitted. Ordering in a `patchesJson6902` list is semantic, not cosmetic.
</details>
