# Section 110 Knowledge Check: Common Expression Language (CEL)

Test your diagnostic reasoning before attempting the lab. Try to answer each question yourself before expanding the explanation.

---

**1.** What is the fundamental difference between what a `validate.pattern` block expresses and what a `validate.cel` expression expresses?

<details>
<summary>Show Answer</summary>

A `pattern` describes **what the resource must look like** — a YAML shape with wildcards and anchors, matched structurally against the resource. A CEL `expression` states **what must be true about the resource** — it evaluates to a boolean, and `true` means admitted. That shift is what makes cross-field comparisons, arithmetic on quantities, before-and-after transition rules, and "at least two of these three" possible at all; none of them is a shape.
</details>

---

**2.** CEL is deliberately not Turing-complete. Why is that a feature rather than a limitation, given where admission control sits?

<details>
<summary>Show Answer</summary>

Admission control runs synchronously in the path of every write to the cluster. In a Turing-complete language, someone can write an expression that never terminates — and an admission check that never terminates is a cluster that stops accepting writes. CEL has no user-controlled loops, no recursion, and no I/O, so every expression provably terminates and the API server can estimate its cost *before* running it and refuse one that is too expensive.
</details>

---

**3.** You write `object.spec.containers.all(c, c.resources.limits['memory'] != '')` and apply it under `Enforce`. A Pod with no `resources` block at all is rejected. Is your policy working?

<details>
<summary>Show Answer</summary>

No — and the message tells you so if you read it: `resulted in error: no such key: limits`. The expression did not evaluate to `false`; it failed to evaluate, and the rule fell closed. CEL raises an error on a missing field rather than returning null. The dangerous part is that a broken policy and a working one look identical from the outside as long as every test resource happens to be non-compliant. Guard optional fields with `has()`, and guard the whole chain: `has(c.resources) && has(c.resources.limits) && 'memory' in c.resources.limits`.
</details>

---

**4.** What does `object.spec.containers.all(c, <predicate>)` evaluate to when `containers` is an empty list, and why might that matter?

<details>
<summary>Show Answer</summary>

`true`, vacuously — that is standard behaviour for a universally-quantified predicate over an empty set. So a rule saying "every container must X" asserts nothing whatsoever about a resource with no containers. If emptiness is itself a violation, you need a separate `size(object.spec.containers) > 0` assertion; `all()` will never catch it.
</details>

---

**5.** Which values does Kyverno bind inside a `validate.cel` expression, and which one lets you write a rule that no `validate.pattern` could ever express?

<details>
<summary>Show Answer</summary>

`object` (the incoming resource), `oldObject` (the resource as it was before this request), `request` (the AdmissionRequest, including `request.operation` and `request.userInfo`), `variables` (your own named sub-expressions), and `namespaceObject` (the full Namespace object the resource is being created in). **`oldObject`** is the one with no pattern equivalent: a pattern only ever sees one resource, so "replicas may never decrease" — `oldObject == null ? true : object.spec.replicas >= oldObject.spec.replicas` — is inexpressible as a shape.
</details>

---

**6.** In a `ValidatingPolicy`, `matchConstraints.resourceRules` has `resources: ["Pod"]` and `operations: ["CREATE"]`. Name both bugs.

<details>
<summary>Show Answer</summary>

First, `resources` takes the lowercase plural **API resource name** — `pods` — the same spelling RBAC uses, not the `Kind` you would write in a `ClusterPolicy` `match` block. Second, omitting `UPDATE` means the policy governs creation only: an already-admitted compliant Pod can be edited into a non-compliant state without the policy objecting at all. Nearly every validation rule wants `["CREATE", "UPDATE"]`.
</details>

---

**7.** What is the difference between a `matchCondition` that evaluates to `false` and a `validation` that evaluates to `false`?

<details>
<summary>Show Answer</summary>

A false `matchCondition` means **this policy does not apply** — the request is skipped, silently and successfully. A false `validation` means **this request is non-compliant** — it is denied, audited, or warned according to `validationActions`. So "Pods in `kube-system` are exempt" belongs in `matchConditions`; folding it into a `validation` expression produces the same outcome but conflates "not my business" with "compliant," and gets progressively harder to read as checks accumulate. `matchConditions` also let Kyverno register a fine-grained webhook so the API server only calls out for requests that could matter.
</details>

---

**8.** A colleague sets `validationActions: [Enforce]` on a `ValidatingPolicy` and it is rejected. What went wrong, and which combination of the real values is also disallowed?

<details>
<summary>Show Answer</summary>

`Enforce` is `ClusterPolicy` vocabulary (`spec.validationFailureAction`). A `ValidatingPolicy` takes a **list** drawn from `Deny`, `Audit`, and `Warn` — `Deny` being the equivalent of `Enforce`. `Deny` and `Warn` together are disallowed, because that would report the same failure twice: once in the API response body and again in an HTTP warning header. `[Audit, Warn]` is allowed and is a sensible rollout posture before switching to `Deny`.
</details>

---

**9.** You write a `ValidatingPolicy` whose `matchConstraints` mention only `pods`. A Deployment with a non-compliant Pod template is rejected anyway. Why, and where do you go to see what was generated?

<details>
<summary>Show Answer</summary>

Autogen — the same Section 090 mechanism, which is a Kyverno feature rather than a `ClusterPolicy` feature. Kyverno generates variants targeting the Pod-controller kinds and rewrites the field paths *inside the CEL expression strings*, so `object.metadata.labels` becomes `object.spec.template.metadata.labels`. Look at `status.autogen.configs` on the policy. You will find the same two groupings as in Section 090: a `defaults` config covering `daemonsets`, `deployments`, `replicasets`, `statefulsets`, and `jobs`, and a separate `cronjobs` config using the deeper `object.spec.jobTemplate.spec.template...` path.
</details>

---

**10.** You set `spec.autogen.validatingAdmissionPolicy.enabled: true`, then submit a non-compliant Pod. The error reads `The pods "vap-bad" is invalid: : ValidatingAdmissionPolicy 'vpol-vap-team-label' with binding 'vpol-vap-team-label-binding' denied request: ...`. What is enforcing this, and what did you give up?

<details>
<summary>Show Answer</summary>

The **API server itself**, via a native Kubernetes `ValidatingAdmissionPolicy` that Kyverno compiled from your policy and activated with a binding. Note what is missing from the message: no `admission webhook ... denied the request`. Kyverno wrote the objects and stepped out of the request path entirely, which removes a whole class of outage — a VAP cannot fail because a webhook is unreachable. What you give up is everything outside the API server's CEL environment: no `context.apiCall` for live cluster data (Section 070), no image-registry lookups (Section 060), no mutation or generation. That is why it is a per-policy switch, not a cluster-wide mode.
</details>

---

**11.** Given only the first line of a rejection message, how do you tell which of Kyverno's three enforcement paths blocked a request?

<details>
<summary>Show Answer</summary>

By the webhook name and the message framing. `admission webhook "validate.kyverno.svc-fail" denied the request:` followed by `resource ... was blocked due to the following policies` is a classic `ClusterPolicy` via Kyverno's webhook. `admission webhook "vpol.validate.kyverno.svc-fail..." denied the request: Policy <name> failed:` is a `ValidatingPolicy` via Kyverno's separate CEL webhook — a different webhook and a one-line body. And `The pods "<name>" is invalid: : ValidatingAdmissionPolicy '<name>' with binding '<name>' denied request:` has no webhook in it at all, because the API server enforced a generated VAP with Kyverno uninvolved.
</details>

---

**12.** Given that `ClusterPolicy` prints a deprecation warning on every apply, should you be writing `ValidatingPolicy` for the KCA?

<details>
<summary>Show Answer</summary>

No. `ClusterPolicy` is fully functional on Kyverno v1.19.1, is what the Writing Policies domain asks you to author, and is what essentially every existing policy repository contains. The warning signposts the direction of the API — the `policies.kyverno.io` family of `ValidatingPolicy`, `MutatingPolicy`, `GeneratingPolicy`, `ImageValidatingPolicy`, and `DeletingPolicy`, one kind per job instead of one kind holding five rule types. Know what it is, be able to read one, and keep authoring `ClusterPolicy`.
</details>

---

## Module 2 — The CEL-Native Policy Family

**M2.1** Name the five kinds in the `policies.kyverno.io` family and the classic construct each replaces.

<details>
<summary>Show Answer</summary>

`ValidatingPolicy` ← `rules[].validate`; `MutatingPolicy` ← `rules[].mutate`; `GeneratingPolicy` ← `rules[].generate`; `ImageValidatingPolicy` ← `rules[].verifyImages`; `DeletingPolicy` ← `ClusterCleanupPolicy` / `CleanupPolicy`. Each also has a `Namespaced*` counterpart, which replaces the `ClusterPolicy`/`Policy` scoping pair with a naming convention rather than a shared spec.
</details>

---

**M2.2** How do you tell, from a policy YAML alone and before reading any rule, which family it belongs to?

<details>
<summary>Show Answer</summary>

The `apiVersion`. `kyverno.io/v1` or `kyverno.io/v2` is the classic family; `policies.kyverno.io/*` is CEL-native. That also predicts the rejection message shape — classic policies are enforced by `validate.kyverno.svc-fail` with the multi-line "resource … was blocked" block, while the CEL family uses `vpol.validate.kyverno.svc-fail` with a one-line `Policy <name> failed:`.
</details>

---

**M2.3** A `MutatingPolicy` has `patchType: ApplyConfiguration` and the expression `Object{ metadata: Object.metadata{ labels: {"managed-by": "x"} } }`. What is that, and what is it the equivalent of?

<details>
<summary>Show Answer</summary>

CEL **object initialization** — you construct the fragment to merge rather than writing it as YAML. `Object` is the root of the resource being mutated and `Object.metadata` is its typed `metadata` sub-object, so the nesting mirrors the path being patched. It is the CEL spelling of a `patchStrategicMerge` fragment. The other patch type, `JSONPatch`, is the RFC 6902 analogue from Section 080.
</details>

---

**M2.4** You split a classic `ClusterPolicy` — which held a mutate rule supplying a default and a validate rule requiring it — into a `MutatingPolicy` and a `ValidatingPolicy`. What did you lose?

<details>
<summary>Show Answer</summary>

Co-location. The rule-type ordering guarantee survives — mutation still runs before validation, because that guarantee is about rule *types*, not policy objects. What is gone is that the two were one object: reviewed as one change, deleted together. Split apart, nothing binds them, so deleting the `MutatingPolicy` leaves the `ValidatingPolicy` rejecting every resource the mutation used to fix, with no tooling to warn you. Name and label paired policies so the relationship is visible to whoever deletes one.
</details>

---

**M2.5** Translating a `ClusterCleanupPolicy` into a `DeletingPolicy`, the schedule and `deletionPropagationPolicy` carry over unchanged. Name two things that do not.

<details>
<summary>Show Answer</summary>

`match` becomes `matchConstraints` (with lowercase plural resource names and explicit `operations`), and `conditions` go from JMESPath `key`/`operator`/`value` triples to **named CEL expressions**. The trap inside that second change: classic cleanup conditions evaluate against **`target`**, while a `DeletingPolicy`'s expressions read **`object`** — consistent with the rest of the CEL family, and easy to miss when translating line by line. The `has()` guard is also needed, since a resource without the field would otherwise error rather than evaluate false.
</details>

---

**M2.6** Does migrating from `ClusterCleanupPolicy` to `DeletingPolicy` change the RBAC you need?

<details>
<summary>Show Answer</summary>

No. The same cleanup controller does the deleting, so it still needs a `ClusterRole` labelled `rbac.kyverno.io/aggregate-to-cleanup-controller: "true"` granting `get`/`list`/`watch`/`delete` on the target resource. Verified on v1.19.1: the Section 100 grant worked unchanged for a `DeletingPolicy`. One observable difference, though — `status` came back empty after a sweep that demonstrably ran, where the classic kind reported `lastExecutionTime` on a cron boundary, so confirm a schedule is firing by observing resources rather than by reading status.
</details>

---

**M2.7** What changes about attestors in an `ImageValidatingPolicy` compared with a classic `verifyImages` rule?

<details>
<summary>Show Answer</summary>

They are **named rather than positional**. Section 060's errors identify trust material by index — `.attestors[1].entries[0]` — whereas here each attestor carries a `name` that `validations` expressions refer to, so a rule with three signers reads as three names and a failure names the one that mattered. The verification backend also becomes an explicit choice between `cosign` and `notary`, which the classic Sigstore-shaped entries did not offer. And `images` is a list of named CEL expressions rather than glob strings, so which images get checked can be computed rather than pattern-matched.
</details>

---

**M2.8** Should you author CEL-native policies for the KCA?

<details>
<summary>Show Answer</summary>

No — keep authoring classic ones. The Writing Policies competencies are framed in classic terms and `ClusterPolicy` is fully functional on v1.19.1; the deprecation warnings signpost direction, not removal. What this family buys you for the exam is the ability to *read* such a policy and say what it does. For a real cluster, adopt deliberately: the family is still moving (`MutatingPolicy` served at both a deprecated `v1alpha1` and `v1` on the same cluster), and a field carrying its classic name does not guarantee it carries its classic behaviour — the `target` → `object` change is the concrete example.
</details>

