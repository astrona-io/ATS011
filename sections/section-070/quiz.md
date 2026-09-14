# Section 070 Knowledge Check: Variables & API Calls in Policies

Test your diagnostic reasoning before attempting the lab. Try to answer each question yourself before expanding the explanation.

---

**1.** You write `match.resources.namespaces: ["{{ request.namespace }}"]`, expecting the rule to somehow match "whatever namespace the request is in." When you apply the policy, no Pod ever triggers the rule. Why?

<details>
<summary>Show Answer</summary>

Variables are not supported in `match` or `exclude` at all — Kyverno's own documentation states this outright, so that the API server can decide which resources need a rule evaluated using only static YAML, without first building a request context. The `{{ }}` braces you wrote are not an error; they're accepted as a literal namespace-glob string. Kyverno is now trying to match a namespace literally named `{{ request.namespace }}`, which doesn't exist, so the rule matches nothing. Any comparison that needs a live value has to move into the rule body — a `preconditions` block or the `validate` rule itself — not `match`/`exclude`.
</details>

---

**2.** A rule's `preconditions` compares `{{ request.oldObject.metadata.labels.locked }}` to `"true"`, with no other guard. A brand-new Pod is created (no prior version exists). What happens when this precondition is evaluated?

<details>
<summary>Show Answer</summary>

`request.oldObject` only exists on UPDATE and DELETE — on a CREATE, there is no previous version of the resource, so the field isn't present in the context at all. Referencing it unconditionally on a CREATE either resolves to an empty/`null` value (which fails an `Equals "true"` comparison harmlessly) or, depending on how deeply nested the path is, can fail outright. This is exactly why `request.oldObject` comparisons are almost always paired with a `request.operation == 'UPDATE'` (or `DELETE`) check first, so the expression is never even evaluated on a CREATE.
</details>

---

**3.** Where does a `context.apiCall` block belong in a `ClusterPolicy`: `spec.context`, or `spec.rules[].context`?

<details>
<summary>Show Answer</summary>

`spec.rules[].context` — context is defined per rule, not once for the whole policy. This was confirmed directly against a live cluster's own CRD schema: `kubectl explain clusterpolicy.spec.context` returns `field "context" does not exist`, while `kubectl explain clusterpolicy.spec.rules.context` resolves. If two rules in the same policy both need the same live data, each rule needs its own `context` entry defined separately.
</details>

---

**4.** A `context.apiCall` uses `urlPath: "/api/v1/namespaces/{{request.namespace}}/pods"` and `jmesPath: "items | length(@)"`. A Pod is being created in a namespace that already has 5 Pods, and a second Pod is being created (in the same request batch) in a different, empty namespace. Does the same policy produce the same count for both?

<details>
<summary>Show Answer</summary>

No — and that's the entire point of scoping the `urlPath` with `{{request.namespace}}`. Each admission request is evaluated independently, and `request.namespace` resolves to the actual namespace of the specific resource being admitted in *that* request. The Pod going into the 5-Pod namespace sees a count around 5; the Pod going into the empty namespace sees a count of 0 (or 1, depending on exactly when the API call lands relative to any other in-flight creates). A hardcoded namespace name in `urlPath`, by contrast, would return the same count regardless of which namespace the Pod actually targets — which is the mistake this scoping is designed to avoid.
</details>

---

**5.** A `context.apiCall` has no `default` field set. The urlPath points at a resource type the admission-controller's ServiceAccount cannot read (a genuine RBAC denial). The policy's `validationFailureAction` is `Enforce`. What happens to a matching resource being admitted?

<details>
<summary>Show Answer</summary>

The request is blocked. A failing `apiCall` — whether from bad RBAC, an invalid `urlPath`, or an unreachable service — causes variable substitution to fail, which fails any condition depending on that variable, and under `Enforce` that failure surfaces as a denied admission request. This was verified directly: the error text names the failure explicitly (`failed to fetch data for APICall: ... permission denied: unknown`) and the resource was rejected, not silently admitted. A `context.apiCall` fails **closed**, not open, unless a `default` value is supplied to give it a fallback.
</details>

---

**6.** Same setup as the previous question, except the `apiCall` now includes `default: 0`. What changes?

<details>
<summary>Show Answer</summary>

The resource is admitted (assuming the rest of the rule's logic treats `0` as passing). `default` provides a fallback value used the moment the API call itself fails, so the variable resolves to `0` instead of raising an error — the condition is evaluated normally against that fallback rather than blocking the request. This was verified by applying the identical failing policy with and without `default: 0`: without it, the request was denied with an `APICall` error; with it, the same request was admitted. Whether fail-open (`default`) or fail-closed (no `default`) is the right choice is a real design decision — for a quota-style check, fail-open silently stops enforcing the limit if the API call breaks, while fail-closed blocks every matching resource until the underlying problem (bad RBAC, a typo'd path) is fixed.
</details>

---

**7.** Kyverno's admission-controller ServiceAccount is bound to the built-in Kubernetes `view` ClusterRole out of the box. A rule's `apiCall` targets `/api/v1/namespaces/{ns}/pods`. Does this specific `apiCall` need any additional RBAC granted to work?

<details>
<summary>Show Answer</summary>

No. `view` already grants `get`/`list`/`watch` on Pods (and almost every other built-in read-only resource) cluster-wide, which was confirmed directly with `kubectl auth can-i list pods --as=system:serviceaccount:kyverno:kyverno-admission-controller -A` returning `yes`. This is a different situation from Section 040's `mutateExistingOnPolicyUpdate`, where the *background controller* needed a hand-granted `ClusterRole` (aggregated via `rbac.kyverno.io/aggregate-to-background-controller`) because mutating existing resources needs `update`/`patch`, verbs `view` doesn't include. Extra RBAC is only needed for an `apiCall` if it targets a resource `view` deliberately excludes (Kubernetes `Secrets`, confirmed to fail the exact same way a bad `urlPath` does) or needs write access.
</details>

---

**8.** A policy has two `context` entries in the same rule: one `apiCall` counting live Pods in a namespace, and one `variable` extracting `request.object.metadata.name`. What does the `variable` entry actually add that writing `{{ request.object.metadata.name }}` inline in the `message` wouldn't?

<details>
<summary>Show Answer</summary>

For a single use, nothing functionally different — both resolve to the same value. The benefit of a named `context.variable` entry shows up once a derived expression is used more than once in the rule, or is long/complex enough that giving it a short name up front makes the rest of the rule more readable, the same reason you'd assign a variable in any programming language rather than repeat an expression each time. It's a genuinely separate mechanism from `apiCall` (no network call — it runs a JMESPath expression against data Kyverno already has in hand), which is why a policy can combine both: one context entry reaching outside the request for live cluster data, and another naming a value already present inside it.
</details>

---

## Module 2 — Context Beyond apiCall

**M2.1** A rule needs to know an image's CPU architecture. Which context type, and why not `apiCall`?

<details>
<summary>Show Answer</summary>

`imageRegistry`. An `apiCall` queries the Kubernetes API server, which has no idea what is inside a container image — that information lives in the registry, in the image's manifest and config blob. The `imageRegistry` entry fetches it during admission, binding an object whose `configData.architecture` and `configData.os` carry the answer.
</details>

---

**M2.2** A `configMap` context entry is named `allowed`. The ConfigMap has a key `registries`. How do you reference it?

<details>
<summary>Show Answer</summary>

`{{ allowed.data.registries }}`. The entry binds the **whole ConfigMap object**, so its keys sit under `.data`, exactly as they do on the ConfigMap itself. Omitting `.data` is a common first mistake and produces an unresolved value rather than an error naming the problem.
</details>

---

**M2.3** What is the security consequence of moving a registry allowlist out of a policy and into a ConfigMap?

<details>
<summary>Show Answer</summary>

The ConfigMap becomes part of the policy's **trust boundary**. Anyone who can edit it can effectively rewrite what the rule enforces, without touching a policy object and without appearing in a policy review. That is a reason to keep policy data in a dedicated namespace writable only by the team that owns the policies — putting it in an application namespace hands the application team a way to edit the rule that governs them.
</details>

---

**M2.4** Name two reasons to use a `variable` context entry.

<details>
<summary>Show Answer</summary>

First, to **name an intermediate result**: an expression repeated across three conditions is three places to update and three chances to disagree. Second — a practical finding on v1.19.1 — to make a value usable in a `message`: referencing a nested field of another context entry directly in a message rendered as an empty string, while the same path worked in a `deny` condition. Binding it through a `variable` entry first and referencing that name produced the value.
</details>

---

**M2.5** Can a later context entry reference an earlier one? Can an earlier one reference a later one?

<details>
<summary>Show Answer</summary>

Yes and no respectively. Context entries are evaluated **top to bottom, once**, before the rule body runs, and each may reference the ones above it. There is no dependency graph — moving an entry above something it depends on leaves that dependency unresolved at the moment it is needed, so reordering a `context` block is not cosmetic.
</details>

---

**M2.6** A rule has four context entries but a precondition that skips the rule for most resources. How many lookups happen per matching request?

<details>
<summary>Show Answer</summary>

All four. Context is fetched before preconditions are evaluated, so a precondition cannot save you the lookup — it only saves you the rule body. The lever that actually reduces lookups is narrowing `match`, which decides whether the rule is consulted at all.
</details>

---

**M2.7** When is `globalReference` the right choice over `apiCall`, and what do you give up?

<details>
<summary>Show Answer</summary>

When the lookup is expensive or external and the data changes slowly relative to how often it is read. A `GlobalContextEntry` performs the lookup on a schedule and caches the result; policies then read the cache instead of repeating the call on every request. What you give up is **freshness** — a cached value is by definition not the current one, so a rule that must see this instant's state (a live pod-count quota, say) cannot use one without changing what it means. Note the cache is also cluster-scoped shared state, and therefore part of the trust boundary in the same way a policy-data ConfigMap is.
</details>

