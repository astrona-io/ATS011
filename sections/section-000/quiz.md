# Section 000 Knowledge Check: Policy Objects and Rule Anatomy

Test your diagnostic reasoning before moving on to Section 010. Try to answer each question yourself before expanding the explanation.

---

**1.** A namespaced `Policy` in `team-staging` has a rule whose `match` block is `kinds: [Pod]` with no namespace restriction at all. Which Pods does it govern?

<details>
<summary>Show Answer</summary>

Only Pods in `team-staging`. Scope is decided by the policy object's kind and namespace, *before* any rule is consulted — a namespaced `Policy` cannot be widened by its own `match` block. This is the most common early confusion: the rule genuinely says "all Pods," and it genuinely only applies to one namespace.
</details>

---

**2.** Why can a namespaced `Policy` never carry a `generate` rule triggered by `kind: Namespace`?

<details>
<summary>Show Answer</summary>

Because a `Namespace` is a cluster-scoped resource. It does not belong to any namespace, so no namespaced policy can select it. The same applies to `ClusterRole`, `PersistentVolume`, and any cluster-scoped CRD kind. A rule triggered by a cluster-scoped resource has to live in a `ClusterPolicy`, regardless of where the resources it creates end up.
</details>

---

**3.** Name the fields every rule carries regardless of its type, and state the one hard constraint on the rule body.

<details>
<summary>Show Answer</summary>

`name` (required, unique within the policy), `match`, `exclude`, `preconditions`, and `context`. The constraint: **exactly one rule body per rule** — a single rule cannot both mutate and validate. Wanting both means writing two rules, which is normal. Note also that `name` is what appears in a rejection message, so it is the only clue a developer gets about which rule stopped them.
</details>

---

**4.** What does a rule with an empty `match` block match?

<details>
<summary>Show Answer</summary>

Nothing. Kyverno never treats an absent or empty `match` as an implicit "everything" — a rule that selects nothing is a no-op. This is a deliberate safety choice: an accidental blank `match` produces a rule that does nothing rather than a rule that governs the entire cluster.
</details>

---

**5.** A policy has two validate rules: one with `failureAction: Enforce`, one with `failureAction: Audit`. A Pod violates both. What does the requester see?

<details>
<summary>Show Answer</summary>

A rejection naming only the **enforced** rule. A rejection message lists the rules that blocked the request, not every rule that failed — the audited failure is recorded in a `PolicyReport` and does not appear in the error at all. If you are diagnosing from the error alone, you are looking at a filtered view of what actually happened.
</details>

---

**6.** Why does per-rule `failureAction` exist when `validationFailureAction` already sets the policy's behaviour?

<details>
<summary>Show Answer</summary>

Because rules inside one policy are often at different maturities. A policy can hold a rule you are confident enough to block on and another you are still tuning; the policy-level field forces both to the same consequence, the per-rule field does not. The policy-level form remains the simpler starting point and is what most existing material uses.
</details>

---

**7.** You want a new rule enforced in `team-prod` but only audited everywhere else, from a single policy. How?

<details>
<summary>Show Answer</summary>

Set `spec.validationFailureAction: Audit` as the default and add `validationFailureActionOverrides` with `action: Enforce` and `namespaces: [team-prod]`. The `namespaces` list accepts globs (`team-*`, `*-prod`), which is how the pattern scales. This inverts the usual rollout: instead of enforcing everywhere at once when you are finally confident, you enforce in one namespace, learn from it, and widen the list.
</details>

---

**8.** Two `ClusterPolicy` objects match the same Pod: `aa-validate-policy` requires a label, `zz-mutate-policy` adds it. The validating one was created first and sorts first alphabetically. Is the Pod admitted?

<details>
<summary>Show Answer</summary>

Yes. Execution order is decided by **rule type**, not by policy name or creation order: every mutate rule on the cluster runs before any validate rule. The mutate rule adds the label, and the validate rule then examines an object that already has it. Neither name ordering nor creation ordering has any bearing on the outcome.
</details>

---

**9.** Where does `verifyImages` sit in that order, and what observable consequence does that have?

<details>
<summary>Show Answer</summary>

With **mutation**, not validation — because a successful verification rewrites the image reference to pin the resolved digest. The observable consequence is that a failed signature check comes back from `mutate.kyverno.svc-fail`, not from a validating webhook. If you are grepping webhook logs for a `verifyImages` rejection, you need the mutating webhook.
</details>

---

**10.** A script runs `kubectl create ns team-x` and then immediately reads the `NetworkPolicy` a `generate` rule is supposed to produce there. It works sometimes. Why?

<details>
<summary>Show Answer</summary>

Because `generate` runs **after** the admission response has already been returned, driven by the background controller rather than the webhook. `kubectl create ns` returning success says nothing about whether generation has happened. The fix is to wait for the generated resource rather than assuming the namespace's creation implies it.
</details>

---

**11.** Two mutate rules in different policies both set the same field to different values. Which wins?

<details>
<summary>Show Answer</summary>

Undefined — ordering *within* a rule type is not something to rely on. The correct response is not to reason harder about which runs first but to make the rules non-overlapping: narrow one rule's `match`, or gate it with a `preconditions` block that is false whenever the other applies. Two rules that can never both fire on one resource have no ordering problem.
</details>

---

**12.** A workload legitimately cannot satisfy a rule. When would you reach for `exclude` rather than `preconditions`?

<details>
<summary>Show Answer</summary>

When the exemption is structural and depends on the resource's *identity* — kind, name, namespace, or labels — and belongs permanently to the policy's own definition. `exclude` is evaluated during resource selection, so an excluded resource produces no report entry at all, not even a `skip`. Reach for `preconditions` instead when the exemption depends on the resource's *data* (an annotation value, a field deep in the spec) that no selector can express — and note that a skipped rule does appear in reports as `skip`, preserving an audit trail.
</details>

---

**13.** You apply a `PolicyException`, get no error, and the exempted Pod is still rejected. What is the first thing to check?

<details>
<summary>Show Answer</summary>

Whether `PolicyException` is enabled at all. Verified on Kyverno v1.19.1: the admission controller ships with `--enablePolicyException=false`, and with the flag off the exception object is created without error — at most a deprecation warning about its API version — and then simply never consulted. Nothing indicates the exception is being ignored. Check with:

```bash
kubectl -n kyverno get deploy kyverno-admission-controller \
  -o jsonpath='{.spec.template.spec.containers[0].args}' | tr ',' '\n' | grep -i exception
```

Enabling it is an install-time decision (a Helm value or a manifest change), which places it in the *Installation, Configuration, and Upgrades* domain rather than *Writing Policies*.
</details>
