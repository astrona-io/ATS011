# Section 030 Knowledge Check: Background Scans

Test your diagnostic reasoning before attempting the lab. Try to answer each question yourself before expanding the explanation.

---

**1.** You apply a brand-new `ClusterPolicy` in `Enforce` mode with `background: true`, requiring every Pod to carry a `team` label. The cluster already has fifty non-compliant Pods running. What happens to those fifty Pods the moment the policy becomes `Ready`?

<details>
<summary>Show Answer</summary>

Nothing happens *to* them. They are not deleted, not blocked, not modified, and not re-admitted. `Enforce` only governs new admission requests -- creates and updates that happen after the policy exists. Within some short delay, the background scan will evaluate all fifty against the rule and record `fail` results for each in their `PolicyReport` objects, but a scan is read-only by design: it produces reports, never actions. The only way `Enforce` ever blocks one of these fifty Pods is if something later tries to update it, triggering a fresh admission request.
</details>

---

**2.** A colleague says: "I don't need `background: true` -- my policy is `Enforce`, so it's already strict." What's wrong with this reasoning?

<details>
<summary>Show Answer</summary>

`Enforce` and `background` answer two completely different questions. `Enforce` decides what happens to a resource *at admission time* if it fails the rule (blocked vs merely logged). `background` decides whether resources that are *not* currently being admitted -- ones that already exist -- get evaluated at all. An `Enforce` policy with `background: false` is maximally strict about new admissions and completely blind to every resource that predates it; it will never produce a single report entry for them, compliant or not.
</details>

---

**3.** You write a rule with a precondition checking `{{ request.operation }} Equals "CREATE"`, and set `background: true`. During a background scan, does this precondition ever evaluate to false for any resource?

<details>
<summary>Show Answer</summary>

No -- not for any resource. There is no live admission request behind a background scan, so Kyverno cannot report a real operation. Instead it supplies a fixed, synthesized value, `CREATE`, for every resource on every scan pass. A precondition checking for `CREATE` is therefore satisfied unconditionally during a scan; it is never actually filtering anything in that context, even though it filters normally at real admission time.
</details>

---

**4.** Same setup, but the precondition instead checks `{{ request.operation }} Equals "UPDATE"`. What result does the background scan produce for a resource that is genuinely, badly non-compliant with the rest of the rule?

<details>
<summary>Show Answer</summary>

`skip`, with a message along the lines of `preconditions not met` -- never `fail`. Since the synthesized operation during a scan is always `CREATE`, it never equals `UPDATE`, so the precondition is always false, and Kyverno correctly reports that the rule's conditions weren't met. This is not a bug or an error state; it is the honest, correct answer to a question a background scan cannot otherwise answer. The practical consequence is sharper than it sounds: a rule gated this way will *never* produce a real `fail` from a background scan, no matter how non-compliant the resource is -- only a genuine admission-time `UPDATE` against that resource can ever trigger a real evaluation.
</details>

---

**5.** You write a rule using `{{ request.userInfo.username }}` in a `deny` condition, and leave `spec.background` at its default. What happens when you run `kubectl apply -f policy.yaml`?

<details>
<summary>Show Answer</summary>

The apply is rejected outright by Kyverno's own policy-validating admission webhook, with an error naming the exact disallowed variable and instructing you to set `spec.background=false`. `request.userInfo` has no plausible value during a background scan -- there is no requester to describe -- so Kyverno refuses to let the policy exist at all with background scanning enabled, rather than silently producing a meaningless result for it. The policy is never created; you must set `background: false` before Kyverno will accept it.
</details>

---

**6.** A single `ClusterPolicy` has two rules: rule A only ever checks `request.object` fields (fine for background scanning), and rule B checks `request.userInfo.username`. Can you set `spec.background: true` for the whole policy so rule A gets scanned, while rule B simply gets skipped during scans?

<details>
<summary>Show Answer</summary>

No. `spec.background` is a single switch for the entire policy, not a per-rule setting. If *any* rule in the policy references a variable that isn't allowed in background mode, the whole policy is rejected at apply time when `background: true`. To get rule A scanned while rule B remains admission-only, they need to live in two separate `ClusterPolicy` objects -- one with `background: true` for rule A, one with `background: false` for rule B.
</details>

---

**7.** Kyverno's background-scan controllers log a default interval of one hour. You apply a new policy against a cluster with a handful of pre-existing Pods and immediately run `kubectl get policyreport -A`. It's empty. Does this mean you need to wait up to an hour to see any results?

<details>
<summary>Show Answer</summary>

No. The one-hour interval governs how often an already-settled policy gets fully re-swept against the cluster afterward -- it is not the delay before the *first* scan. In practice, the first pass against a newly-applied policy tends to happen within seconds to tens of seconds, well under a minute for a small cluster, because Kyverno reconciles a newly-created or newly-`Ready` policy right away rather than waiting for the next scheduled tick. If the report is still empty after a short poll, look at whether the policy is actually `Ready` and whether `match` is selecting the resources you expect, rather than assuming you simply haven't waited long enough.
</details>

---

**8.** True or false: a background scan can update or delete a non-compliant resource to bring it into line with a policy.

<details>
<summary>Show Answer</summary>

False. A background scan for a `validate` rule is strictly read-only -- it evaluates a resource and writes a result into a `PolicyReport`/`ClusterPolicyReport`; it never mutates or removes the resource it's reporting on, regardless of whether the policy is `Enforce` or `Audit`. (Kyverno does have separate mechanisms -- `mutate` rules with `mutateExistingOnPolicyUpdate`, and cleanup policies covered in Section 100 -- that can act on existing resources, but plain background scanning of a `validate` rule is observation only.)
</details>
