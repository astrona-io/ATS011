# Section 000: Policy Objects and Rule Anatomy (Primer)

> [!NOTE]
> This section is a **primer**, not one of the eleven KCA *Writing Policies* competencies. It exists because several policy-level topics — scoping, failure actions, rule ordering, exemptions — have no natural home in a curriculum organised by rule type, yet turn up attached to questions about every one of them. Start here if you are new to Kyverno; skip it if you already write policies daily.

Every other section of this course teaches a *rule type*. This one teaches the object the rules live inside, and the decisions that are made at that level rather than inside any individual rule.

Three of those decisions account for a large share of "why is this policy not doing what I wrote":

* **Scope** is fixed by the policy object, not by the rule. A namespaced `Policy` whose `match` says `kinds: [Pod]` with no namespace restriction still governs exactly one namespace, and no `match` block can widen it.
* **The failure action** exists at three levels — the whole policy, a single rule, and a per-namespace override — and the one you pick determines whether a violation blocks a developer or quietly lands in a report.
* **Execution order** across policies is fixed by Kyverno and is not configurable. Every mutate rule on the cluster runs before any validate rule, which is why a mutate rule in one policy can silently satisfy a validate rule in another.

---

## What You Will Master

By completing this section, you will acquire the policy-level competencies the rest of the course assumes:

* **Policy Objects and Failure Actions:** How to choose between `ClusterPolicy` and `Policy`, what a namespaced policy structurally cannot reach, the fields every rule shares regardless of type, and how `validationFailureAction`, per-rule `failureAction`, and `validationFailureActionOverrides` combine to let you enforce a rule in one namespace while auditing it in another.
* **Ordering and Exemptions:** How Kyverno sequences mutate, validate, and generate across every policy on the cluster, why ordering *within* a rule type is undefined and what to do instead, and how to choose between `exclude`, `preconditions`, and a `PolicyException` when a workload legitimately needs to be exempt.

---

## The Learning & Lab Path

This section has one module. It is reading plus a free-exploration playground — there is no graded lab, because nothing here is a competency the exam tests in isolation:

### 1. Policy Objects and Rule Anatomy

* **Module Reader:** **[Module 1: Policy Objects and Rule Anatomy](./module-01/course.md)**
    1. [Policy Objects and Rule Anatomy](./module-01/course-01-policy-objects-and-rule-anatomy.md)
    2. [Failure Actions and Staged Rollout](./module-01/course-02-failure-actions-and-rollout.md)
    3. [Rule Ordering and Carving Out Exceptions](./module-01/course-03-rule-ordering-and-exceptions.md)
* **Free-Exploration Playground:** an ungraded sandbox with a `kind` cluster, Kyverno already running, no policies, and two empty namespaces (`team-prod`, `team-staging`) for per-namespace failure-action experiments.
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-000/module-01/playground
    astrona destroy ats-011-playground-000
    ```

---

## Ready for Assessment?

Test your understanding of the policy object itself before moving on to Section 010:

* **[Take the Section 000 Knowledge Check Quiz](./quiz.md)**
