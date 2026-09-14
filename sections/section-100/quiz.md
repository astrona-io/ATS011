# Section 100 Knowledge Check: Cleanup Policies

Test your diagnostic reasoning before attempting the lab. Try to answer each question yourself before expanding the explanation.

---

**1.** Structurally, what does a `CleanupPolicy` have that a `ClusterPolicy` does not — and what does it lack?

<details>
<summary>Show Answer</summary>

It has a required `schedule` field holding a cron expression, and it exposes the candidate resource as `target`. It lacks a `rules` array entirely, along with `validate`, `mutate`, `generate`, `verifyImages`, and `validationFailureAction` — the policy *is* the rule, and the action is always deletion. It is also never consulted during admission: a separate `kyverno-cleanup-controller` Deployment executes it on the schedule.
</details>

---

**2.** You apply a perfectly well-formed `ClusterCleanupPolicy` targeting Pods to a fresh cluster as `cluster-admin`, and it is rejected: `admission webhook "kyverno-cleanup-controller.kyverno.svc" denied the request: cleanup controller has no permission to delete kind Pod`. Whose permissions are the problem, and how do you fix it?

<details>
<summary>Show Answer</summary>

Not yours — the `kyverno-cleanup-controller` ServiceAccount's. Kyverno ships that account with almost no deletion rights by design, and its cleanup webhook performs a `SubjectAccessReview` against itself at policy-apply time, refusing the policy rather than letting it sit there silently deleting nothing. Being cluster-admin makes no difference; you get the identical error. The fix is to create a `ClusterRole` carrying the label `rbac.kyverno.io/aggregate-to-cleanup-controller: "true"` granting `get`, `list`, `watch`, and `delete` on `pods`, which Kubernetes RBAC aggregation then merges into Kyverno's `kyverno:cleanup-controller` role.
</details>

---

**3.** Your grant `ClusterRole` has the aggregation label and `verbs: ["delete"]` on `resources: ["Pod"]`, but the policy is still rejected with the same error. What are the two mistakes?

<details>
<summary>Show Answer</summary>

First, RBAC `resources` are API resource names — plural and lowercase — so it must be `pods`, not `Pod`. The `Kind` spelling belongs in the policy's `match` block, not in a `ClusterRole`. Second, `delete` alone is not enough: the controller has to `list` candidates to find them and `get` them to evaluate conditions, so the rule needs `get`, `list`, `watch`, and `delete`.
</details>

---

**4.** A `ClusterCleanupPolicy` has `schedule: "* * * * *"`. A matching Pod is created at 15:26:40. When is it deleted?

<details>
<summary>Show Answer</summary>

At the next cron boundary — 15:27:00 — not 60 seconds after creation. A cleanup policy is a periodic sweep, not a trigger: on each tick the controller lists what matches and deletes it. One minute is the finest granularity a cron expression offers, so "up to a minute late" is the tightest timing guarantee any cleanup policy can give, and a schedule like `0 3 * * *` means up to a day late. You can confirm the tick times on `status.lastExecutionTime`, which always lands on a cron boundary.
</details>

---

**5.** You want to clean up only Pods whose `status.phase` is `Succeeded`. Can you express that in `match`? If not, where does it go, and what variable do you write it against?

<details>
<summary>Show Answer</summary>

No — `match` selects on kind, namespace, name, and labels, and `status.phase` is none of those. It goes in `spec.conditions`, using the same `all`/`any` operator entries you know from preconditions, written against **`target`** rather than `request.object`: `key: "{{ target.status.phase }}"`, `operator: Equals`, `value: Succeeded`. There is no admission request during a sweep, so `request.object` has nothing to resolve.
</details>

---

**6.** Why is it bad practice to leave `match` as bare `kinds: [Pod]` cluster-wide and do all the real filtering in `conditions`, even though it produces the correct result?

<details>
<summary>Show Answer</summary>

Because the two are evaluated at different places and costs. `match` becomes the selector the controller uses when listing candidates from the API server; `conditions` are evaluated per-resource inside Kyverno afterwards. A wide-open `match` makes every tick list and evaluate every Pod in the cluster. Push everything expressible as a kind, namespace, name, or label selector into `match`, and reserve `conditions` for what no selector can reach.
</details>

---

**7.** A colleague labels a debug Pod `cleanup.kyverno.io/ttl=30s` on a cluster where no `CleanupPolicy` exists and no cleanup RBAC has been granted. What happens, and how would you diagnose it?

<details>
<summary>Show Answer</summary>

The Pod is admitted normally and then never deleted. The TTL label needs the same `delete` permission a policy does — it is the same controller — but the `ttl-label` webhook only logs the problem rather than rejecting the resource, so nothing surfaces on the Pod: no error, no event, no status. The only trace is a line in the cleanup controller's log reading `doesn't have required permissions for deletion ... logger=ttl-label/validate`. Diagnose it with `kubectl -n kyverno logs deploy/kyverno-cleanup-controller | grep 'required permissions'`. This asymmetry is worth remembering: a missing grant makes a *policy* fail loudly at apply time and a *TTL label* fail silently forever.
</details>

---

**8.** What values does `cleanup.kyverno.io/ttl` accept, and what is the timing guarantee?

<details>
<summary>Show Answer</summary>

Either a duration measured from the resource's `creationTimestamp` (`30s`, `15m`, `2h`, `5d`) or an absolute RFC 3339 timestamp (`2026-09-14T15:30:00Z`). Deletion happens on the TTL controller's own reconciliation sweep — `ttlReconciliationInterval`, one minute by default — which is separate from any policy's cron schedule. So the same "up to a minute late" caveat applies: eligibility at 15:27:10 means deletion at the following reconciliation, not on the second.
</details>

---

**9.** A `ClusterCleanupPolicy` deletes `Job` resources with `deletionPropagationPolicy: Orphan`. What happens to the Pods those Jobs created?

<details>
<summary>Show Answer</summary>

They are left behind, ownerless, and keep running. `Orphan` tells the API server to delete the owner without garbage-collecting its dependents. `Background` (delete the owner immediately, let the garbage collector clean up dependents afterwards) or `Foreground` (delete dependents first, remove the owner only once they are gone) are almost always what you actually want when cleaning up a kind that owns other resources. Setting this field explicitly matters exactly when the target has dependents.
</details>

---

**10.** Applying a `ClusterCleanupPolicy` on Kyverno v1.19.1 prints `kyverno.io/v2 ClusterCleanupPolicy is deprecated ... migrate to DeletingPolicy`. Should you write `DeletingPolicy` instead for the KCA?

<details>
<summary>Show Answer</summary>

No. The warning signposts the newer CEL-based `DeletingPolicy` / `NamespacedDeletingPolicy` in the `policies.kyverno.io` group — the same family as the `ValidatingPolicy` types in Section 110 — but `CleanupPolicy` and `ClusterCleanupPolicy` remain fully functional on this version and are what the Writing Policies domain asks you to author. It is the same situation as the `ClusterPolicy` deprecation warning you have seen since Section 010. The underlying model also transfers directly: `DeletingPolicy` still schedules with cron, still selects resources, and still requires the cleanup controller to hold delete permission on the target kind — what changes is JMESPath conditions becoming CEL expressions.
</details>
