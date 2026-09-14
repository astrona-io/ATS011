# Section 030: Background Scans

Welcome to Section 030. Section 010 ended on a pointed observation: admission control only ever looks at what's arriving right now, and every Pod already running when a policy is written is completely invisible to it. This section is the answer to that gap.

Kyverno's `spec.background` field (default `true`) turns a `ClusterPolicy` from a one-time gate into something that also periodically walks back through every resource already living in the cluster, checking each one against the same rules, and recording what it finds -- without blocking, deleting, or modifying anything it looks at. This is how a team safely rolls a brand-new rule out against a cluster that has years of pre-existing, non-compliant resources in it: turn the rule on, let the background scan build a complete inventory of what already violates it, and only then decide what to do about `Enforce`.

---

## What You Will Master

By completing this section, you will acquire the two core competencies that separate "I wrote a validate rule" from "I understand when that rule actually runs":

* **How Background Scanning Works:** The difference between admission-time evaluation and periodic re-evaluation, how results surface as `PolicyReport` (namespaced) and `ClusterPolicyReport` (cluster-scoped) objects, and how `Enforce`/`Audit` and `background` are three independent knobs, not one.
* **The Limits of a Scan:** Why a rule that depends on live admission-request context -- `request.operation`, and especially `request.userInfo` -- cannot be answered the same way during a background scan as it can at real admission time, what Kyverno actually does about it (a synthesized value in one case, an outright rejection at `kubectl apply` in the other), and when `spec.background: false` is the honest choice.

---

## The Learning & Lab Path

This section has one module, paired with hands-on practice against a real `kind` cluster running Kyverno:

### 1. Background Scanning

* **Module Reader:** **[Module 1: Background Scanning](./module-01/course.md)**
    1. [What Background Scanning Actually Does](./module-01/course-01-what-background-scans-do.md)
    2. [Request Context and the Limits of a Scan](./module-01/course-02-request-context-and-limits.md)
* **Practice Lab Sandbox:** **`sections/section-030/module-01/labs/lab-01`**
* **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-030/module-01/labs/lab-01
    ```
* **Hands-on Objective:** Write an `Audit`-mode `ClusterPolicy` with `background: true` requiring every Pod to carry a `team` label, then prove -- by reading `PolicyReport` objects, not by running any new Pods yourself -- that the scan reaches back and reports on Pods that existed before the policy did, all without touching them.
* **Free-Exploration Playground:** an ungraded sandbox with the same `kind` cluster and Kyverno already running, and no policies on it — linked from the top of the module reader.
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-030/module-01/playground
    astrona destroy ats-011-playground-030
    ```

---

## Ready for Assessment?

Test your theoretical knowledge and diagnostic reasoning before tackling the background-scans lab mission:

* **[Take the Section 030 Knowledge Check Quiz](./quiz.md)**
