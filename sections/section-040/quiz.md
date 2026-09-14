# Section 040 Knowledge Check: Mutation Rules

Test your diagnostic reasoning before attempting the lab. Try to answer each question yourself before expanding the explanation.

---

**1.** A `mutate.patchStrategicMerge` block sets `spec.containers` as a plain list with one entry: `- imagePullPolicy: IfNotPresent` (no `name` field). Applied against a Pod with two containers, what happens?

<details>
<summary>Show Answer</summary>

The Pod is rejected outright, with an error like `The Pod "..." is invalid: spec.containers: Required value`. Without a `name` (or the `(name)` anchor), Kyverno tries to strategic-merge the fragment using the container list's merge key, `name`, finds nothing matching an empty name, and inserts it as a brand-new container missing its own required `name` field — which the API server then rejects. This is a meaningfully worse failure mode than a positional mismatch in a `validate.pattern`: a missing anchor on a `patchStrategicMerge` list doesn't just fail to reach every element, it can corrupt the resource being created.
</details>

---

**2.** A `ClusterPolicy` mutate rule sets `metadata.labels.managed-by: platform`. An incoming Pod already carries `managed-by: team-x`. What ends up in the persisted object?

<details>
<summary>Show Answer</summary>

`managed-by: platform`. This was verified directly: `patchStrategicMerge` has no "only if absent" behavior for a scalar field — the patch's value always replaces whatever the requester submitted. If you need "set this only when missing," you need to gate the rule with a precondition that checks whether the field already exists; a plain `patchStrategicMerge` always overwrites.
</details>

---

**3.** True or false: a `validate` rule requiring a label can never pass for a Pod that omits that label, even if another rule on the cluster injects it via `mutate`.

<details>
<summary>Show Answer</summary>

False. Kyverno runs every mutate rule on the cluster, across every `ClusterPolicy`, before it runs any validate rule — this holds even across two entirely separate `ClusterPolicy` objects, regardless of their names or creation order. A validate rule requiring a label that some mutate rule injects will see the label already present, because the mutate rule has already run by the time any validate rule evaluates the object.
</details>

---

**4.** You split a mutate rule and a validate rule into two separate `ClusterPolicy` objects, and deliberately name the validate policy so it sorts alphabetically *before* the mutate policy. Does this change which one runs first?

<details>
<summary>Show Answer</summary>

No. This was tested directly to rule out "policies run in name/creation order" as the actual mechanism. Kyverno's mutate-before-validate ordering is a fixed processing guarantee, not a consequence of how policies happen to be named or when they were created — every mutate rule on the cluster still finishes first, regardless of policy naming.
</details>

---

**5.** What does `mutate.mutateExistingOnPolicyUpdate: true` actually trigger on, and how is that different from an ordinary mutate rule?

<details>
<summary>Show Answer</summary>

It triggers on the `ClusterPolicy` itself being created or updated — not on a new admission request to the target resource. An ordinary mutate rule only ever acts when something submits a create/update for a resource matching its `match` block. A `mutateExistingOnPolicyUpdate` rule additionally reaches out, via its `mutate.targets` block, to resources that already exist and patches them the moment the policy changes — resources that were never touched by anyone, admission-wise, at that moment.
</details>

---

**6.** You apply a brand-new `mutateExistingOnPolicyUpdate` policy targeting Pods, and the `kubectl apply` is rejected immediately with an "auth check fails" error naming `system:serviceaccount:kyverno:kyverno-background-controller`. What's missing, and how do you grant it?

<details>
<summary>Show Answer</summary>

The `kyverno-background-controller` service account needs `update` permission (in practice, granted alongside `get`/`list`/`watch`) on the target resource kind. Kyverno checks this permission at policy-apply time and refuses to accept a rule it already knows it can't execute. You grant it by creating a `ClusterRole` with the rules you need and the label `rbac.kyverno.io/aggregate-to-background-controller: "true"` — Kubernetes' own `ClusterRole` aggregation folds it into Kyverno's `kyverno:background-controller` role automatically; you never edit that role directly.
</details>

---

**7.** A `mutateExistingOnPolicyUpdate` rule's `patchStrategicMerge` sets both a label and a container's `imagePullPolicy` on already-running Pods in the same fragment. For a Pod where the `imagePullPolicy` actually needs to change, what happens to the label?

<details>
<summary>Show Answer</summary>

It doesn't get updated either — for that Pod. This was observed directly: the entire patch becomes a single API `Update` call, and a running Pod's `imagePullPolicy` is not on Kubernetes' short allow-list of fields an existing Pod's spec can have changed (essentially just a container's `image`, `activeDeadlineSeconds`, additions to `tolerations`, and `terminationGracePeriodSeconds` moving off negative). If any part of the patch represents a real change to an immutable field, the API server rejects the *whole* update, including the otherwise-legal label change riding along with it — and that rejection is logged only inside the `kyverno-background-controller` Pod, never surfaced to any interactive session.
</details>

---

**8.** Given the previous question's answer, what's the realistic way to apply a container-level default (like a new `imagePullPolicy`) to Pods that already exist?

<details>
<summary>Show Answer</summary>

You generally can't, directly — Kubernetes itself refuses to let any client, including Kyverno's background controller, change most Pod spec fields after creation. The realistic options are: limit `mutateExistingOnPolicyUpdate` on Pods to genuinely mutable fields (metadata — labels and annotations), or target a higher-level, fully-mutable object instead, such as a `Deployment`'s Pod template (where a change triggers a normal rolling update that replaces the Pods), a `ConfigMap`, or a `Secret`. Waiting for or forcing a natural replacement of the Pod (e.g. a rolling restart) is the only way to actually get a new container-level field onto Pods a controller manages.
</details>

---

## Module 2 — Per-Element Mutation and Idempotency

**M2.1** When is `mutate.foreach` required rather than the `(name)` anchor?

<details>
<summary>Show Answer</summary>

When the new value must be **computed from the element being patched**. The `(name)` anchor applies one fixed fragment to every matching element, which is fine for "every container gets `imagePullPolicy: IfNotPresent`" but cannot express "every container's image gets prefixed with our mirror", where each container ends up with a different value derived from the one it had. `foreach` binds the current item to `element`, which is what makes that computation possible.
</details>

---

**M2.2** Inside a `foreach` doing a `patchStrategicMerge` on `containers`, why does the fragment usually include `name: "{{ element.name }}"`?

<details>
<summary>Show Answer</summary>

Because it is still a strategic merge, and strategic merge reconciles the `containers` list by its merge key, `name`. Without the key the fragment matches no existing container and is **inserted as a new nameless one**, which the API server then rejects with `spec.containers: Required value` — the same failure mode as omitting the `(name)` anchor in Module 1, for the same underlying reason.
</details>

---

**M2.3** A rule prefixes every container image with `mirror.local/`. A Pod is created correctly, then someone adds an unrelated label to it. What does the image look like afterwards?

<details>
<summary>Show Answer</summary>

`mirror.local/mirror.local/nginx:1.27` — verified on v1.19.1. The `match` block said `kinds: [Pod]` with no `operations` restriction, so the rule matched the UPDATE too and re-applied its transformation to an already-transformed value. Nothing errored and nothing warned; the Pod now references an image that does not exist. This is the defining hazard of mutation and has no equivalent in validation: a validate rule asked twice gives the same answer, a mutate rule applied twice gives a different result.
</details>

---

**M2.4** What makes a mutation idempotent, and which common transformations are not?

<details>
<summary>Show Answer</summary>

Setting a field to a **constant** is idempotent — applying `imagePullPolicy: IfNotPresent` twice leaves it `IfNotPresent`. Deriving a new value from the old one generally is not: prefixing, appending, incrementing, and wrapping all compound on each application. Any rule of that second kind needs an explicit guard or an `operations` restriction, because it will be re-evaluated on every UPDATE and by `mutateExistingOnPolicyUpdate` on a schedule you did not initiate.
</details>

---

**M2.5** Why must the guard against re-prefixing live inside the `foreach` entry rather than at rule level?

<details>
<summary>Show Answer</summary>

Because rule-level preconditions are evaluated once against the whole resource, and can therefore only ask "does *any* container need prefixing". That is the wrong question for a Pod holding one already-prefixed container and one that is not — the rule would either skip both or process both. A `preconditions` block nested inside the `foreach` entry is evaluated per element, against that element, which is the granularity the problem actually has.
</details>

---

**M2.6** Two mutate rules in different policies both write `spec.containers[*].image`. Which wins, and what should you do about it?

<details>
<summary>Show Answer</summary>

Undefined — ordering *within* a rule type is not something to rely on, and there is deliberately no priority field to set. The fix is to make the rules non-overlapping rather than to reason about order: narrow one rule's `match`, or give each a precondition that is false whenever the other applies. (Ordering *between* rule types is fixed and reliable: every mutate rule on the cluster runs before any validate rule.)
</details>

