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
