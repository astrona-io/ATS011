# Section 050 Knowledge Check: Generation Rules

Test your diagnostic reasoning before attempting the lab. Try to answer each question yourself before expanding the explanation.

---

**1.** A `ClusterPolicy` has a `generate` rule matching `kind: Namespace`. You run `kubectl create ns team-a` and it returns instantly. You immediately run `kubectl get networkpolicy -n team-a` and see nothing. Did the rule fail?

<details>
<summary>Show Answer</summary>

Not necessarily. Generation is asynchronous and runs through Kyverno's background controller, not the admission controller — `kubectl create ns` returns as soon as the Namespace itself is admitted, before the generate rule has necessarily finished creating its downstream resource. In practice the generated resource typically appears within a few seconds. Always poll for it with a short timeout rather than checking once immediately after the trigger command returns.
</details>

---

**2.** What is the difference in job between `generate.data` and `generate.clone`?

<details>
<summary>Show Answer</summary>

They are two mutually exclusive ways of answering the same question — "what content goes into the generated resource?" `generate.data` is a literal manifest written directly into the policy. `generate.clone` instead names a `namespace`/`name` of an existing source resource already living somewhere in the cluster, and Kyverno copies it. A single `generate` block uses one or the other, never both.
</details>

---

**3.** In a `generate` rule targeting `kind: Namespace`, what does `"{{request.object.metadata.name}}"` typically get used for?

<details>
<summary>Show Answer</summary>

It's used as `generate.namespace` — the destination namespace for the generated resource. `request.object` refers to the trigger resource (the Namespace that was just created), so `request.object.metadata.name` is that Namespace's own name. Without it, a rule would need one hardcoded destination namespace, which defeats the entire purpose of a rule meant to cover every namespace that will ever be created.
</details>

---

**4.** With `synchronize: true` on a `generate.clone` rule, you edit the *source* resource after several clones already exist. What happens to those existing clones?

<details>
<summary>Show Answer</summary>

They update automatically, with no new trigger event required. `synchronize: true` keeps every already-generated clone in sync with its source going forward — this was confirmed directly: patching a source ConfigMap's data propagated to a clone in an unrelated, already-existing namespace within a few seconds, with nobody touching that namespace at all.
</details>

---

**5.** With `synchronize: true`, someone runs `kubectl edit` directly against a generated clone and changes its content. What happens?

<details>
<summary>Show Answer</summary>

The edit is silently reverted back to match the source, typically within a few seconds. The API server accepts the write — there's no `validate` rule blocking it — but Kyverno's background controller detects the drift and overwrites the clone back to the source's content. `synchronize: true` means Kyverno owns the clone's content going forward, not merely that it copied it once.
</details>

---

**6.** True or false: with `synchronize: true`, deleting the generated clone directly (leaving its namespace alone) causes it to disappear permanently.

<details>
<summary>Show Answer</summary>

False. `synchronize: true` makes Kyverno treat the clone as a resource it is responsible for keeping present and correct — deleting it directly gets it recreated from the source, typically within a few seconds. This is the single cleanest way to prove `synchronize: true` is actually active, and it's exactly what this section's capstone lab grades on. With `synchronize: false` (the default), a direct delete is permanent — the clone was only ever a one-time copy.
</details>

---

**7.** True or false: `synchronize: true` works by attaching a Kubernetes `ownerReference` from the generated resource to the trigger, so that deleting the trigger cascades a standard Kubernetes garbage-collection delete of the generated resource.

<details>
<summary>Show Answer</summary>

False. Inspecting a generated resource's `metadata.ownerReferences` on a live cluster shows it empty — Kyverno links a generated resource back to its trigger and source purely through its own `generate.kyverno.io/*` labels and an internal `UpdateRequest` object, never through `ownerReferences`. When the trigger is a Namespace and the generated resource lives inside that same Namespace, deleting the Namespace does make the generated resource disappear — but only because Kubernetes' own namespace-deletion controller wipes out everything inside a deleted Namespace, regardless of Kyverno and regardless of `synchronize`, and even if no Kyverno policy existed at all.
</details>

---

**8.** You need every namespace to get a `ResourceQuota` with the exact same fixed CPU/memory limits, and you never want an application team to be able to override it by editing their own copy. Which generation approach — `data` or `clone`, and with or without `synchronize` — fits best, and why?

<details>
<summary>Show Answer</summary>

`generate.data` with `synchronize: true` is the better fit. There's no existing source object to copy — the content is fixed and known up front, which is exactly what `data` is for — and `synchronize: true` ensures that if a team edits or deletes their `ResourceQuota` directly, Kyverno reverts or recreates it rather than letting the override stick. `generate.clone` would only make sense if the content already existed as a real object somewhere else that you wanted copied instead of retyped into the policy — such as a shared ConfigMap or Secret maintained centrally.
</details>

---

## Module 2 — Generating for What Already Exists

**M2.1** A generate rule creating a default-deny `NetworkPolicy` per namespace is applied to a cluster with fifty existing namespaces. How many are protected?

<details>
<summary>Show Answer</summary>

None, unless `generateExisting: true` is set. Without it the rule is purely forward-looking: it fires when a Namespace is created, and the namespaces that already existed are never triggers. The gap stays open until each is somehow recreated, which for most namespaces is never.
</details>

---

**M2.2** `generateExisting`, `spec.background`, and `mutateExistingOnPolicyUpdate` are three different field names. What is the single idea behind all three?

<details>
<summary>Show Answer</summary>

*Does this rule also apply to what is already here?* Each rule type exposes the same admission-time-versus-background choice under a different name: validation as `spec.background`, mutation as `mutateExistingOnPolicyUpdate`, generation as `generateExisting`. In every case the background path is executed by a different controller with different permissions from the admission webhook, which is why the background forms can require RBAC that the admission-time forms do not.
</details>

---

**M2.3** Distinguish `generateExisting` from `synchronize`.

<details>
<summary>Show Answer</summary>

`generateExisting` is about **the past**: does this rule reach resources that already exist? `synchronize` is about **the future**: once generated, is the downstream kept in step with its source, reverted when edited, and recreated when deleted? They are independent. A one-time backfill that teams may then customise is `generateExisting: true` with `synchronize: false`; a strictly-maintained resource in new namespaces only is the reverse.
</details>

---

**M2.4** You delete a `ClusterPolicy` whose generate rule had created a default-deny `NetworkPolicy` in fifty namespaces. What happens to those NetworkPolicies?

<details>
<summary>Show Answer</summary>

They are **deleted**, within seconds — verified on v1.19.1. This is the opposite of most people's intuition, and the consequence is severe: deleting one policy object removed baseline ingress isolation from every namespace it had generated into, as a side effect of an action that looked like it only affected policy. `orphanDownstreamOnPolicyDelete: true` reverses it and leaves the generated resources in place.
</details>

---

**M2.5** For which kinds of generated resource is the default deletion behaviour wrong?

<details>
<summary>Show Answer</summary>

Safety controls — anything whose absence is a weaker state than its presence. A default-deny `NetworkPolicy`, a `ResourceQuota`, a `LimitRange`, a `PodDisruptionBudget`: an unmanaged, slightly stale one still does its job, while a deleted one does nothing. The default is right for resources that only make sense as an extension of the policy, such as a generated `ConfigMap` of policy-derived settings, which would otherwise linger as something nobody can explain. The question to ask: *if this resource stops being managed, is the cluster better off with it or without it?*
</details>

---

**M2.6** Why does Kubernetes' garbage collector not handle generated-resource cleanup, and why does that matter?

<details>
<summary>Show Answer</summary>

Because generated resources carry **no `ownerReferences`** — Kyverno tracks the trigger/source/downstream relationship through its own `generate.kyverno.io/*` labels and `UpdateRequest` objects. So deletion is Kyverno actively removing resources it knows it created, not the API server collecting orphans. That is precisely why the behaviour is configurable at all: an `ownerReference` relationship would give you no such switch.
</details>

---

**M2.7** Under `synchronize: true`, what else can make a generated resource disappear besides deleting the policy?

<details>
<summary>Show Answer</summary>

The **trigger ceasing to match** the rule — for example a namespace relabelled so the rule's `match` no longer selects it. With `synchronize: true` the set of generated resources tracks the set of matching triggers in both directions: widening `match` creates more, narrowing it destroys some. Editing a generate rule's `match` block is therefore a destructive operation on a scale the edit itself does not look like.
</details>

