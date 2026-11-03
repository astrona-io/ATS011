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

Each module has a reader, a free-exploration playground and a graded lab. Every module ends with a summary page and a mission that points to its lab. The labs are marked UNTESTED until they have been run against a live cluster.

### 1. Background Scanning

* **Module Reader:** **[Module 1: Background Scanning](./module-01/course.md)**
    1. [What Background Scanning Actually Does](./module-01/course-01-what-background-scans-do.md)
    2. [Request Context and the Limits of a Scan](./module-01/course-02-request-context-and-limits.md)
    3. [Summary](./module-01/course-03-summary.md)
* **Practice Lab Sandbox:** **`sections/section-030/module-01/labs/lab-01`** (`ats-011-lab-031`, UNTESTED)
* **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-030/module-01/labs/lab-01
    ```
* **Hands-on Objective:** Solve this question against the `kind` cluster provisioned for this lab (Kyverno is already installed and running in the `kyverno` namespace).
* **Free-Exploration Playground:** an ungraded sandbox with the same `kind` cluster and Kyverno already running, and no policies on it.
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-030/module-01/playground
    astrona destroy ats-011-playground-030
    ```

### Capstone

* **Capstone Lab:** **`sections/section-030/capstone/labs/lab-01`** (`ats-011-lab-030`)
* **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-030/capstone/labs/lab-01
    ```

---

## Ready for Assessment?

Test your theoretical knowledge with the section quiz. It is a graded quiz with a pass score of 70 percent:

* **[Take the Section 030 Knowledge Check Quiz](./quiz.yaml)**
