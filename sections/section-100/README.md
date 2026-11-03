# Section 100: Cleanup Policies

Every policy type you have written so far answers a question about a resource *arriving*: should this be admitted, what should it look like once admitted, what else should exist because of it. Cleanup policies answer a completely different question — **what should stop existing, and when?**

A `CleanupPolicy` is not an admission rule at all. It has no `validate`, no `mutate`, no `generate`, and it never appears in an admission webhook. Instead it carries a **cron schedule**, and on every tick a dedicated controller lists the resources its `match` block selects, applies any `conditions` you wrote, and deletes what is left. Expired PR preview namespaces, finished Jobs, scratch ConfigMaps, stale test Pods — this is the tool for all of it.

Two consequences fall straight out of that design and account for most of the confusion around this policy type. First, cleanup is not free the way admission control is: the cleanup controller must hold real RBAC permission to delete the kind you target, and Kyverno checks this **when you apply the policy**, refusing it outright rather than failing quietly later. Second, timing is cron-shaped — a resource is deleted at the next scheduled tick, not the instant it becomes eligible, so "roughly within a minute" is the tightest guarantee a `* * * * *` schedule can give you.

---

## What You Will Master

By completing this section, you will acquire the two core competencies every Kyverno policy author needs around cleanup:

* **Scheduling Deletion Safely:** How to write a `ClusterCleanupPolicy` and a namespaced `CleanupPolicy`, express a cron `schedule`, select victims with `match`/`exclude` (including label selectors), and — critically — grant the cleanup controller the RBAC it needs via an aggregating `ClusterRole`, recognising the exact admission error you get when you forget.
* **Narrowing and Alternatives:** How to filter beyond `match` with a `conditions` block over the `target` variable, when the per-resource `cleanup.kyverno.io/ttl` label is a better fit than a whole policy, what `deletionPropagationPolicy` controls, and where the newer CEL-based `DeletingPolicy` fits relative to the `CleanupPolicy` the exam asks about.

---

## The Learning & Lab Path

Each module has a reader, a free-exploration playground and a graded lab. Every module ends with a summary page and a mission that points to its lab. The labs are marked UNTESTED until they have been run against a live cluster.

### 1. Cleanup Policies

* **Module Reader:** **[Module 1: Cleanup Policies](./module-01/course.md)**
    1. [Schedules, Matching, and the RBAC Requirement](./module-01/course-01-schedules-matching-and-rbac.md)
    2. [Conditions, TTL Labels, and Deletion Semantics](./module-01/course-02-conditions-ttl-and-deletion-semantics.md)
    3. [Summary](./module-01/course-03-summary.md)
* **Practice Lab Sandbox:** **`sections/section-100/module-01/labs/lab-01`** (`ats-011-lab-101`, UNTESTED)
* **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-100/module-01/labs/lab-01
    ```
* **Hands-on Objective:** Solve this question against the `kind` cluster provisioned for this lab (Kyverno is already installed and running in the `kyverno` namespace).
* **Free-Exploration Playground:** an ungraded sandbox with the same `kind` cluster and Kyverno already running, and no policies on it.
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-100/module-01/playground
    astrona destroy ats-011-playground-100
    ```

### Capstone

* **Capstone Lab:** **`sections/section-100/capstone/labs/lab-01`** (`ats-011-lab-100`)
* **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-100/capstone/labs/lab-01
    ```

---

## Ready for Assessment?

Test your theoretical knowledge with the section quiz. It is a graded quiz with a pass score of 70 percent:

* **[Take the Section 100 Knowledge Check Quiz](./quiz.yaml)**
