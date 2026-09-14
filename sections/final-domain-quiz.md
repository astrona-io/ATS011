# KCA Writing Policies — Final Domain Certification Quiz

This is the closed-book simulator for the **Writing Policies** domain (32% of the KCA). It draws on every section and deliberately mixes them, the way the real exam does — no question announces which section it comes from. The KCA itself is a 90-minute, online proctored, **multiple-choice** exam, so this format is the closest rehearsal the repository offers.

**How to take it properly:**

* **Closed book.** No Kyverno docs, no cluster, no notes, no earlier chapters.
* **Time limit: 80 minutes** for all 40 questions. If you run long, that is itself the result — exam pressure is part of what is being measured.
* Write your answer down *before* expanding the explanation. Recognising a correct answer is not the same skill as producing one.
* Each explanation ends with the section that covers it, so a wrong answer tells you exactly where to go back to.

**Scoring:** count a question correct only if you got *every* part of it right — most are deliberately multi-part.

| Score | Reading |
| :--- | :--- |
| 36–40 | Domain-ready. |
| 29–35 | Solid. Re-read the sections your misses cluster in. |
| 20–28 | Work the labs again for the weak sections before retaking. |
| under 20 | Re-read the chapters; the labs will not stick yet. |

---

## Section A — Validation and Preconditions

**1.** A `validate.pattern` requires `metadata.labels.team: "?*"`. A developer applies a Pod with `labels: {team: ""}`. Is it admitted? What if the `labels` key is absent entirely?

<details>
<summary>Show Answer</summary>

Rejected in both cases. `?*` means "one character, then anything" — i.e. a non-empty string — so an empty value fails it, and an absent `labels` map fails it too because the pattern's path cannot be satisfied. `*` alone would be the weaker check that an empty string can satisfy.

*Covered in Section 010.*
</details>

---

**2.** You need a rule that only applies when the request is an `UPDATE` **and** the resource already carries the label `env=prod`. Which part goes in `match` and which in `preconditions`, and why can't both go in the same place?

<details>
<summary>Show Answer</summary>

Both *could* technically be expressed in `preconditions`, but the idiomatic and efficient split is: the label selector goes in `match` (it is a selector the API server and webhook configuration can act on directly), and the operation check goes in `preconditions` as `key: "{{ request.operation }}"`, `operator: Equals`, `value: UPDATE`. The reason `match` alone cannot carry everything is that `match` selects on resource identity — kind, name, namespace, labels — while `preconditions` can evaluate arbitrary JMESPath over the request and the resource's own field values.

*Covered in Section 020.*
</details>

---

**3.** A policy has `background: true` and a rule whose `preconditions` reference `{{ request.userInfo.username }}`. What happens during a background scan?

<details>
<summary>Show Answer</summary>

There is no admission request during a background scan, so `request.userInfo` has nothing to resolve. The rule cannot be meaningfully evaluated against existing resources — Kyverno skips it or reports an error rather than inventing a user. Any rule that depends on request-only context (`request.operation`, `request.userInfo`, `request.roles`) is an admission-time rule only, regardless of what `background` is set to.

*Covered in Section 030.*
</details>

---

**4.** What is the difference in observable outcome between `validationFailureAction: Audit` and `Enforce`, and where do you look to see the result of the former?

<details>
<summary>Show Answer</summary>

`Enforce` rejects the request at admission — the developer sees an error and nothing is created. `Audit` admits the resource and records the violation in a `PolicyReport` (namespaced resources) or `ClusterPolicyReport` (cluster-scoped ones), which you read with `kubectl get policyreport -A`. `Audit` is the correct posture while rolling out a new policy against a live cluster; `Enforce` is what actually prevents anything.

*Covered in Sections 010 and 030.*
</details>

---

## Section B — Mutation and JSON Patches

**5.** A `patchStrategicMerge` fragment lists `containers: [{imagePullPolicy: IfNotPresent}]` with no `name` field. What happens to a two-container Pod?

<details>
<summary>Show Answer</summary>

The whole Pod is rejected by the API server. Strategic merge reconciles the `containers` list by its merge key, `name`. Your fragment has no `name`, matches no existing container, and is therefore *inserted* as a brand new list element — a container with no name — which the API server rejects with `spec.containers: Required value`. A missing anchor on a strategic-merge list is not a silent no-op; it corrupts the resource. Use `(name): "*"` to mean "every container."

*Covered in Section 040.*
</details>

---

**6.** Write the JSON Pointer path that targets the annotation `policy.example.com/reviewed`, and explain why the obvious spelling is wrong.

<details>
<summary>Show Answer</summary>

`/metadata/annotations/policy.example.com~1reviewed`. The obvious spelling puts a literal `/` in the key, which RFC 6901 reads as a path separator — so the pointer would resolve as four segments and look for a `reviewed` key inside an object stored under `policy.example.com`. `/` escapes as `~1` and `~` escapes as `~0`; nothing else is special, so dots and dashes are left alone.

*Covered in Section 080.*
</details>

---

**7.** Three JSON Patch rules target a path that does not exist on the incoming resource: one `add`, one `remove`, one `replace`. Describe the outcome of each on Kyverno v1.19.1, and state the design rule you should follow regardless.

<details>
<summary>Show Answer</summary>

`add` succeeds and creates the missing parent (and overwrites the value if the key already exists). `remove` is a silent no-op. `replace` rejects the entire admission request with `replace operation does not apply: doc is missing path ...`. The design rule: an unconditional `add` is always safe and needs no guard, while anything destructive (`remove`, `replace`) should be gated behind a `preconditions` check that the field is actually present — so the rule behaves identically whether the implementation is lenient or strict.

*Covered in Section 080.*
</details>

---

**8.** What does `mutateExistingOnPolicyUpdate: true` with a `targets` block do that an ordinary `mutate` rule cannot?

<details>
<summary>Show Answer</summary>

An ordinary `mutate` rule only ever sees resources passing through admission — it cannot touch anything that already existed when the policy was applied. `mutateExistingOnPolicyUpdate: true` plus a `targets` block makes Kyverno's background controller retroactively patch resources that already exist. Note that this needs the background controller to hold RBAC permission to update the target kind, which it does not have for arbitrary kinds by default.

*Covered in Section 040.*
</details>

---

## Section C — Generation, Images, and Variables

**9.** A `generate` rule with `synchronize: true` creates a ConfigMap in each new Namespace. An operator edits one of the generated ConfigMaps by hand. What happens, and what happens if they delete it outright?

<details>
<summary>Show Answer</summary>

With `synchronize: true`, Kyverno reverts the manual edit — the generated resource is continuously reconciled against its source, so hand edits do not survive. Deleting it outright causes Kyverno to recreate it (self-healing). With `synchronize: false`, the resource is created once and then left alone entirely: edits persist and a deletion is permanent.

*Covered in Section 050.*
</details>

---

**10.** A `verifyImages` rule has `mutateDigest: true`. A Pod is submitted referencing `registry.example.com/app:v1.2`. What does the persisted Pod spec contain, and why does it matter for security?

<details>
<summary>Show Answer</summary>

The image reference is rewritten to the resolved digest form — `registry.example.com/app:v1.2@sha256:...`. It matters because a tag is a mutable pointer: the image you verified at admission is not necessarily the image that gets pulled later if someone republishes the tag. Pinning the digest into the spec means the kubelet pulls exactly the bytes whose signature was verified.

*Covered in Section 060.*
</details>

---

**11.** A rule needs to make a decision based on how many Pods already exist in the requesting namespace. Which mechanism provides that, and what is the one thing about it that is *not* like a normal policy field?

<details>
<summary>Show Answer</summary>

`context.apiCall`, which queries the live Kubernetes API during rule evaluation and binds the result to a variable you then reference with `{{ }}`. What is unlike a normal policy field is that its value is fetched at *evaluation* time from live cluster state, not baked into the policy — so the same unchanged policy can produce different verdicts on different days. It also needs the Kyverno service account to hold read permission on the resource being queried.

*Covered in Section 070.*
</details>

---

**12.** In a JMESPath variable, why is `{{ request.object.metadata.annotations."example.com/owner" || '' }}` written with both the double quotes and the `|| ''`?

<details>
<summary>Show Answer</summary>

The double quotes are JMESPath's key-quoting syntax, required because the key contains a `/` that JMESPath would otherwise read as syntax. The `|| ''` supplies an empty-string fallback: on a resource with no `annotations` block at all, the left side resolves to nothing, and a bare unresolved variable is a substitution *error*, not an empty value. Comparing the result against `""` with `NotEquals` is then the standard "does this key exist" idiom.

*Covered in Sections 070 and 080.*
</details>

---

## Section D — Autogen

**13.** A rule's `match.any` block lists `kinds: [Pod, Namespace]` in a single entry. How many autogenerated rules does Kyverno produce?

<details>
<summary>Show Answer</summary>

None — `status.autogen` comes back empty. The moment a `match` or `exclude` entry names any kind other than `Pod`, Kyverno declines to autogenerate rather than producing a partial or best-effort rewrite. Two separate single-kind rules are required if you want both a Pod-level and a Namespace-level check.

*Covered in Section 090.*
</details>

---

**14.** A Pod-only rule checks `metadata.labels.team`. Give the rewritten path for a Deployment and for a CronJob, and explain why they are two separately-generated rules rather than one.

<details>
<summary>Show Answer</summary>

Deployment (and DaemonSet, Job, ReplicaSet, ReplicationController, StatefulSet): `spec.template.metadata.labels.team`. CronJob: `spec.jobTemplate.spec.template.metadata.labels.team`. Those six kinds all hold their Pod template directly at `spec.template` and can therefore share one generated rule; a CronJob nests its template one level deeper inside a Job spec, so its rewrite differs and it gets a rule of its own.

*Covered in Section 090.*
</details>

---

**15.** You scope autogen to `Deployment` only with the `pod-policies.kyverno.io/autogen-controllers` annotation, explicitly excluding `Job`. A non-compliant `Job` is then submitted. Is the Job admitted? Does it ever run?

<details>
<summary>Show Answer</summary>

The `Job` object is admitted — no rule was generated for `Job`, so nothing intercepts it. But the original Pod-matching rule still governs every bare Pod submission, and the Pod the Job controller then tries to create *is* a bare Pod submission. That Pod is rejected repeatedly and the Job sits failing forever with `FailedCreate` events. Scoping autogen narrows which controller objects get their own generated rule; it never narrows what the original Pod rule matches.

*Covered in Section 090.*
</details>

---

**16.** You write a Pod-only rule whose `pattern` already nests fields under `spec.template`, anticipating the Deployment you actually want to protect. Autogen fires. What is the generated rule checking?

<details>
<summary>Show Answer</summary>

`spec.template.spec.template...` — a path that exists on nothing. Autogen performs a fixed mechanical rewrite and does not interpret what your pattern means, so it wraps whatever sits under `spec` one level deeper regardless. The generated rule is silently useless against every controller kind, with no error raised. Always write the Pod rule against the Pod's own native shape and let autogen produce the controller-shaped path.

*Covered in Section 090.*
</details>

---

## Section E — Cleanup

**17.** You apply a well-formed `ClusterCleanupPolicy` targeting Pods as cluster-admin and it is rejected with `cleanup controller has no permission to delete kind Pod`. Whose permissions, and what exactly do you create to fix it?

<details>
<summary>Show Answer</summary>

The `kyverno-cleanup-controller` ServiceAccount's — not yours; a cluster-admin gets the identical error. Kyverno's cleanup webhook runs a `SubjectAccessReview` against itself at apply time and refuses the policy rather than letting it silently delete nothing. The fix is a `ClusterRole` labelled `rbac.kyverno.io/aggregate-to-cleanup-controller: "true"` granting `get`, `list`, `watch`, and `delete` on `pods` — lowercase plural resource name, and all four verbs, since the controller must list candidates before it can delete them.

*Covered in Section 100.*
</details>

---

**18.** A cleanup policy has `schedule: "* * * * *"`. A matching Pod is created at 15:26:40. When is it deleted, and what is the tightest timing guarantee any cleanup policy can offer?

<details>
<summary>Show Answer</summary>

At the next cron boundary — 15:27:00 — not 60 seconds after creation. Cleanup is a periodic sweep, not a trigger: each tick lists what matches and deletes it. One minute is cron's finest granularity, so "up to a minute late" is the tightest possible guarantee, and `0 3 * * *` means up to a day late. `status.lastExecutionTime` always shows a cron boundary.

*Covered in Section 100.*
</details>

---

**19.** You want to clean up only Pods whose `status.phase` is `Succeeded`. Where does that go, and which variable do you write it against?

<details>
<summary>Show Answer</summary>

In `spec.conditions`, written against **`target`** — `key: "{{ target.status.phase }}"`, `operator: Equals`, `value: Succeeded`. It cannot go in `match`, which selects only on kind, namespace, name, and labels. And it is `target`, not `request.object`: there is no admission request during a sweep.

*Covered in Section 100.*
</details>

---

**20.** A Pod is labelled `cleanup.kyverno.io/ttl=30s` on a cluster with no cleanup RBAC granted. What happens, and how is that failure different from the same mistake made with a policy?

<details>
<summary>Show Answer</summary>

The Pod is admitted and then never deleted — silently. The TTL label needs the same `delete` permission a policy does, but the `ttl-label` webhook only logs the problem instead of rejecting the resource, so nothing shows on the Pod: no error, no event, no status. The only evidence is a cleanup-controller log line reading `doesn't have required permissions for deletion`. A missing grant makes a *policy* fail loudly at apply time and a *TTL label* fail silently forever.

*Covered in Section 100.*
</details>

---

**21.** A cleanup policy deletes `Job` resources with `deletionPropagationPolicy: Orphan`. What happens to the Pods those Jobs created?

<details>
<summary>Show Answer</summary>

They are left behind, ownerless, and keep running. `Orphan` deletes the owner without garbage-collecting its dependents. `Background` (owner first, garbage collector follows) or `Foreground` (dependents first, owner last) are almost always what you want when cleaning up a kind that owns other resources.

*Covered in Section 100.*
</details>

---

## Section F — CEL

**22.** Give one requirement that `validate.pattern` genuinely cannot express, and explain what it is about a pattern that makes it impossible.

<details>
<summary>Show Answer</summary>

Any requirement comparing a resource to its own previous state — "`replicas` may only ever increase" is the canonical example. A pattern describes the shape of *one* resource; it has no access to the resource as it was before the request, so there is nothing to compare against. In CEL this is `oldObject == null ? true : object.spec.replicas >= oldObject.spec.replicas`. Cross-field comparison and arithmetic on quantities are two more classes of requirement a shape cannot state.

*Covered in Section 110.*
</details>

---

**23.** `object.spec.containers.all(c, c.resources.limits['memory'] != '')` is applied under `Enforce`. A Pod with no `resources` block is rejected. Explain why calling this "working" is wrong, and what you should have noticed at apply time.

<details>
<summary>Show Answer</summary>

The rejection message reads `resulted in error: no such key: limits` — your own `message` never appeared. The expression did not evaluate to `false`; it failed to evaluate, and the rule fell closed. From outside, a broken policy and a working one look identical for as long as every resource you test happens to be non-compliant. At apply time Kyverno type-checked the expression against the matched kind and warned: `ERROR: <input>:1:42: undefined field 'limits'`, with a caret pointing at the offset — while still creating the policy. The fix is `has(c.resources) && has(c.resources.limits) && 'memory' in c.resources.limits`.

*Covered in Section 110.*
</details>

---

**24.** A CEL rule matches `kinds: [Pod]` with no `operations` restriction, and its expression reads `object.spec.containers`. A namespace containing a Pod is stuck `Terminating` forever. Explain the chain, and say whether adding `has()` guards would have prevented it.

<details>
<summary>Show Answer</summary>

A `match` block that says nothing about operations matches `DELETE` too. On a DELETE there is no incoming resource — `object` is null — so `object.spec.containers` errors with `no such key: spec`, and under `Enforce` the error denies the DELETE. Pods become undeletable cluster-wide, and since namespace deletion works by deleting its contents, the namespace never terminates. `has()` guards would **not** have prevented it: the failure is on `object` itself, before any predicate runs — a `variables` entry dereferencing `object.spec` fails first. The fix is restricting `match` to `operations: [CREATE, UPDATE]`.

*Covered in Section 110.*
</details>

---

**25.** `object.spec.containers.all(c, <predicate>)` on a resource whose container list is empty. What does it evaluate to, and what is the practical consequence?

<details>
<summary>Show Answer</summary>

`true`, vacuously — the standard result for a universally-quantified predicate over an empty set. So a rule saying "every container must X" asserts nothing at all about a resource with no containers. If emptiness is itself a violation you need a separate `size(object.spec.containers) > 0` check; `all()` will never catch it.

*Covered in Section 110.*
</details>

---

**26.** In a `ValidatingPolicy`, what is the difference between a `matchCondition` that evaluates to `false` and a `validation` that evaluates to `false`?

<details>
<summary>Show Answer</summary>

A false `matchCondition` means *the policy does not apply* — the request is skipped, silently and successfully. A false `validation` means *the request is non-compliant* — denied, audited, or warned per `validationActions`. An exemption ("Pods in this namespace are out of scope") belongs in `matchConditions`; folding it into a validation expression produces the same outcome but conflates "not my business" with "compliant." `matchConditions` also let Kyverno register a fine-grained webhook so the API server only calls out on requests that could matter.

*Covered in Section 110.*
</details>

---

**27.** A `ValidatingPolicy` has `matchConstraints.resourceRules` with `resources: ["Pod"]` and `operations: ["CREATE"]`, and `validationActions: [Enforce]`. Name all three errors.

<details>
<summary>Show Answer</summary>

(1) `resources` takes the lowercase plural API resource name — `pods` — the same spelling RBAC uses, not the `Kind`. (2) Omitting `UPDATE` means an admitted compliant Pod can be edited into a non-compliant state unchallenged; nearly every validation rule wants `["CREATE", "UPDATE"]`. (3) `Enforce` is `ClusterPolicy` vocabulary — this type takes a list drawn from `Deny`, `Audit`, and `Warn`, with `Deny` being the equivalent. (`Deny` and `Warn` may not be combined.)

*Covered in Section 110.*
</details>

---

**28.** A rejection reads: `The pods "app" is invalid: : ValidatingAdmissionPolicy 'vpol-pod-baseline' with binding 'vpol-pod-baseline-binding' denied request: ...`. What enforced this, what did you configure to make it happen, and what capability did you give up?

<details>
<summary>Show Answer</summary>

The **API server itself**, via a native Kubernetes `ValidatingAdmissionPolicy` that Kyverno compiled from your policy and activated with a binding — note the complete absence of `admission webhook ... denied the request` from the message. It comes from `spec.autogen.validatingAdmissionPolicy.enabled: true` on a `ValidatingPolicy` (or `validate.cel.generate: true` inside a `ClusterPolicy`, which produces a `cpol-`-prefixed VAP instead of a `vpol-` one). What you give up is everything outside the API server's CEL environment: no `context.apiCall` for live cluster data, no image-registry lookups, no mutation or generation. In exchange, enforcement can no longer fail because a webhook is unreachable.

*Covered in Section 110.*
</details>

---

## Section G — Cross-cutting

**29.** Three rejections, three different first lines. Match each to what enforced it:
(a) `admission webhook "validate.kyverno.svc-fail" denied the request:` followed by `resource ... was blocked due to the following policies`
(b) `admission webhook "vpol.validate.kyverno.svc-fail" denied the request: Policy <name> failed:`
(c) `The pods "<name>" is invalid: : ValidatingAdmissionPolicy '<name>' with binding '<name>' denied request:`

<details>
<summary>Show Answer</summary>

(a) A classic `ClusterPolicy`, enforced by Kyverno's validating webhook. (b) A `ValidatingPolicy` from the `policies.kyverno.io` group, enforced by Kyverno's separate CEL webhook — a different webhook name and a one-line body. (c) A generated `ValidatingAdmissionPolicy`, enforced by the API server with Kyverno not in the request path at all — which is why no webhook is named.

*Covered in Sections 010 and 110.*
</details>

---

**30.** Every `ClusterPolicy` and `ClusterCleanupPolicy` you apply on Kyverno v1.19.1 prints a deprecation warning pointing at the `policies.kyverno.io` types. What should you actually author for the KCA, and why is that not a contradiction?

<details>
<summary>Show Answer</summary>

Keep authoring `ClusterPolicy` and `ClusterCleanupPolicy`. Both are fully functional on this version, both are what the Writing Policies domain examines, and both are what essentially every existing policy repository contains. The warning signposts the direction of the API — `ValidatingPolicy`, `MutatingPolicy`, `GeneratingPolicy`, `ImageValidatingPolicy`, and `DeletingPolicy`, one kind per job instead of one kind holding five rule types — rather than announcing a removal. The professional position is to know what the newer types are, be able to read one, and keep writing the ones the exam and the ecosystem use.

*Covered in Sections 100 and 110.*
</details>

---

## Section H — Policy Objects, Anchors, and Advanced Rules

**31.** A namespaced `Policy` in `team-staging` has a rule whose `match` is `kinds: [Pod]` with no namespace restriction. Which Pods does it govern, and why?

<details>
<summary>Show Answer</summary>

Only Pods in `team-staging`. Scope comes from the policy **object** — its kind and namespace — and is fixed before any rule is consulted; a namespaced `Policy` cannot be widened by its own `match` block. The same constraint means a namespaced policy can never govern cluster-scoped resources such as `Namespace`, which is why a `generate` rule triggered by Namespace creation must be a `ClusterPolicy`.

*Covered in Section 000.*
</details>

---

**32.** You need a rule enforced in `team-prod` and merely audited everywhere else, from one policy. Which field, and what is the rollout advantage?

<details>
<summary>Show Answer</summary>

`validationFailureActionOverrides`: set `spec.validationFailureAction: Audit` as the default and add an override with `action: Enforce` and `namespaces: [team-prod]`. The advantage is that it inverts the usual rollout — instead of auditing everywhere and then flipping the whole cluster to `Enforce` in one uncomfortable step, you enforce in one namespace, learn, and widen the list. The `namespaces` field accepts globs, so `team-*` scales it.

*Covered in Section 000.*
</details>

---

**33.** A policy has one validate rule with `failureAction: Enforce` and one with `failureAction: Audit`. A Pod violates both. What appears in the error returned to `kubectl`?

<details>
<summary>Show Answer</summary>

Only the **enforced** rule. A rejection message lists the rules that blocked the request, not every rule that failed; the audited failure is recorded in a `PolicyReport` and is absent from the error entirely. Diagnosing from the error alone therefore gives you a filtered view of what actually happened.

*Covered in Section 000.*
</details>

---

**34.** Convert "a Deployment may have at most 3 replicas" into a `deny` condition, and name the trap.

<details>
<summary>Show Answer</summary>

`key: "{{ request.object.spec.replicas }}"`, `operator: GreaterThan`, `value: 3`. The trap is the **inversion**: `validate.pattern` describes what must be true to *pass*, while `deny.conditions` describes what must be true to *fail*. Writing the requirement rather than its negation produces a rule that rejects every compliant Deployment and admits every oversized one.

*Covered in Section 010, Module 2.*
</details>

---

**35.** Under deny polarity, which is stricter — `conditions.any` or `conditions.all`?

<details>
<summary>Show Answer</summary>

`any`. Because a true condition rejects, `any` rejects on a single true condition while `all` requires every condition to hold first. This reads backwards from the intuition built on `match.any`, and choosing `all` where `any` was meant produces a rule that still rejects *something* — just far less than intended, with nothing to signal the mistake.

*Covered in Section 010, Module 2.*
</details>

---

**36.** A pattern contains `(image): "*:latest"` next to `imagePullPolicy: Always`. A container runs `nginx:1.27` with `imagePullPolicy: IfNotPresent`. Admitted or rejected — and what does that tell you about the anchored field?

<details>
<summary>Show Answer</summary>

Admitted. The conditional anchor did not match, so its sibling fields were never examined — the identical `IfNotPresent` would have been rejected on a `:latest` image. The anchored field is the "if", not a requirement: `(image): "*:latest"` does not demand that images be `:latest`, it selects the ones that are.

*Covered in Section 010, Module 3.*
</details>

---

**37.** A Pod has two containers and only the second defines a `readinessProbe`. Compare the verdict under `^(containers)`, under a `foreach`, and under a plain positional list pattern.

<details>
<summary>Show Answer</summary>

`^()` **admits** it — the existence anchor needs at least one matching element and one matches. A `foreach` **rejects** it — the body runs against every element and fails on the one without a probe. A plain positional pattern checks only index 0 and **rejects** it for a third, unrelated reason: position 0 does not match. Three constructs, three different meanings on the same resource.

*Covered in Section 010, Modules 1 and 3.*
</details>

---

**38.** Which Pod Security Standard level *requires* fields rather than merely forbidding configurations, and what is the right way to exempt a single control?

<details>
<summary>Show Answer</summary>

`restricted`. `baseline` blocks known privilege-escalation paths and an ordinary application usually passes it unchanged; `restricted` additionally requires `runAsNonRoot`, `allowPrivilegeEscalation: false`, dropped capabilities, and a seccomp profile, which is why most off-the-shelf images fail it. To exempt one control, use `podSecurity.exclude` with a `controlName` — optionally narrowed by `images` or by `restrictedField`/`values` — rather than dropping the whole namespace to `baseline`, which trades one exemption for a dozen.

*Covered in Section 010, Module 4.*
</details>

---

**39.** A rule prefixes every container image with a mirror hostname. A Pod is created correctly, then someone adds an unrelated label. What is the image now, and what are the two fixes?

<details>
<summary>Show Answer</summary>

`mirror.local/mirror.local/nginx:1.27` — the rule matched the UPDATE and re-applied its transformation to an already-transformed value, silently. The two fixes: a `preconditions` block **inside the `foreach` entry** that skips any element already prefixed (per-element granularity a rule-level precondition cannot give you), and `operations: [CREATE]` in `match` to remove the re-application path. Use both where both apply — mutate rules are also re-run by `mutateExistingOnPolicyUpdate` on a schedule you did not initiate.

*Covered in Section 040, Module 2.*
</details>

---

**40.** You delete a `ClusterPolicy` whose generate rule had created a default-deny `NetworkPolicy` in fifty namespaces. What happens, and which field changes it?

<details>
<summary>Show Answer</summary>

Every one of those NetworkPolicies is **deleted**, within seconds — removing baseline ingress isolation cluster-wide as a side effect of what looked like a policy-only action. `orphanDownstreamOnPolicyDelete: true` leaves them in place instead, and is the right setting for any downstream that is a safety control, since an unmanaged default-deny still denies while a deleted one denies nothing. None of this is Kubernetes garbage collection: generated resources carry no `ownerReferences`, and Kyverno tracks them through its own labels and `UpdateRequest` objects — which is exactly why the behaviour is a field you can set.

*Covered in Section 050, Module 2.*
</details>

---

## After the quiz

Count your score against the table at the top. Whatever you missed, the explanation names the section — go back to that chapter and then redo its lab, in that order. Reading alone will not fix a miss that came from never having watched the behaviour happen.
