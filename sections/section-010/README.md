# Section 010: Validation Rules

Welcome to Section 010, the front door of the Writing Policies domain. Validation is where most people meet Kyverno for the first time: a `ClusterPolicy` that looks at incoming resources and either lets them through, rejects them, or just quietly logs the violation.

Kubernetes' built-in admission control gives you a binary choice — accept or reject a `kubectl apply` — but it has no opinion about *what a good resource looks like* inside your organization. Kyverno's `validate` rule fills that gap declaratively: instead of writing a webhook in Go, you describe the shape a resource must match, in YAML that looks almost like the resource itself.

---

## What You Will Master

By completing this section, you will acquire the two core competencies every Kyverno policy author needs first:

* **Pattern-Based Validation:** How to write a `ClusterPolicy` with a `validate.pattern` block, use wildcard operators (`?`, `*`) and conditional operators (`>`, `<=`, `!-`) inside a pattern, and choose between `Enforce` and `Audit` failure actions.
* **Multi-Path Validation:** How to accept more than one valid shape with `anyPattern`, iterate over list fields (like a Pod's `containers`) with `foreach`, and write messages that surface *why* a resource was rejected.
* **Assertion Trees and Manifest Verification:** How to validate with `validate.assert` trees and check signed manifests with `validate.manifests`.

---

## The Learning & Lab Path

Each module has a reader, a free-exploration playground and a graded lab. Every module ends with a summary page and a mission that points to its lab. The labs are marked UNTESTED until they have been run against a live cluster.

### 1. Pattern-Based Validation

* **Module Reader:** **[Module 1: Pattern-Based Validation](./module-01/course.md)**
    1. [The ClusterPolicy Object and Its Audience](./module-01/course-01-the-clusterpolicy-object.md)
    2. [The Pattern Block and What Failure Costs](./module-01/course-02-the-pattern-block-and-failure-actions.md)
    3. [anyPattern, foreach & Failure Messages](./module-01/course-03-anypattern-foreach-and-messages.md)
    4. [Summary](./module-01/course-04-summary.md)
* **Practice Lab Sandbox:** **`sections/section-010/module-01/labs/lab-01`** (`ats-011-lab-011`, UNTESTED)
* **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-010/module-01/labs/lab-01
    ```
* **Hands-on Objective:** Solve this question against the `kind` cluster provisioned for this lab (Kyverno is already installed and running in the `kyverno` namespace).
* **Free-Exploration Playground:** an ungraded sandbox with the same `kind` cluster and Kyverno already running, and no policies on it.
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-010/module-01/playground
    astrona destroy ats-011-playground-010
    ```

### 2. Deny Rules and the Condition Vocabulary

* **Module Reader:** **[Module 2: Deny Rules and the Condition Vocabulary](./module-02/course.md)**
    1. [Deny Rules and the Inversion](./module-02/course-01-deny-rules-and-the-inversion.md)
    2. [The Condition Operator Vocabulary](./module-02/course-02-condition-operator-vocabulary.md)
    3. [Summary](./module-02/course-03-summary.md)
* **Practice Lab Sandbox:** **`sections/section-010/module-02/labs/lab-01`** (`ats-011-lab-012`, UNTESTED)
* **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-010/module-02/labs/lab-01
    ```
* **Hands-on Objective:** Kyverno is installed. Write one `ClusterPolicy` named `deployment-guardrails` with `validationFailureAction: Enforce` and `background: false`. It applies to Deployments in the namespace `shop` and uses `validate.deny` in three rules:
* **Free-Exploration Playground:** an ungraded sandbox with the same `kind` cluster and Kyverno already running, and no policies on it.
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-010/module-02/playground
    astrona destroy ats-011-playground-0102
    ```

### 3. Validation Anchors

* **Module Reader:** **[Module 3: Validation Anchors](./module-03/course.md)**
    1. [Conditional and Equality Anchors](./module-03/course-01-conditional-and-equality-anchors.md)
    2. [Existence, Negation, and Global Anchors](./module-03/course-02-existence-negation-and-global-anchors.md)
    3. [Summary](./module-03/course-03-summary.md)
* **Practice Lab Sandbox:** **`sections/section-010/module-03/labs/lab-01`** (`ats-011-lab-013`, UNTESTED)
* **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-010/module-03/labs/lab-01
    ```
* **Hands-on Objective:** Kyverno is installed. Write one `ClusterPolicy` named `pod-anchors` with `validationFailureAction: Enforce` and `background: false`. It applies to Pods in the namespace `anchors` and has four `validate.pattern` rules:
* **Free-Exploration Playground:** an ungraded sandbox with the same `kind` cluster and Kyverno already running, and no policies on it.
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-010/module-03/playground
    astrona destroy ats-011-playground-0103
    ```

### 4. The podSecurity Subrule

* **Module Reader:** **[Module 4: The podSecurity Subrule](./module-04/course.md)**
    1. [Profiles, Levels, and Versions](./module-04/course-01-podsecurity-profiles-and-levels.md)
    2. [Excluding Controls, and PSS Versus PSA](./module-04/course-02-excluding-controls-and-psa.md)
    3. [Summary](./module-04/course-03-summary.md)
* **Practice Lab Sandbox:** **`sections/section-010/module-04/labs/lab-01`** (`ats-011-lab-014`, UNTESTED)
* **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-010/module-04/labs/lab-01
    ```
* **Hands-on Objective:** Kyverno is installed and the namespace `pss-lab` exists. Write a `ClusterPolicy` named `pss-baseline` with `validationFailureAction: Enforce` and `background: false` with one `validate.podSecurity` rule for Pods in `pss-lab`:
* **Free-Exploration Playground:** an ungraded sandbox with the same `kind` cluster and Kyverno already running, and no policies on it.
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-010/module-04/playground
    astrona destroy ats-011-playground-0104
    ```

### 5. Assertion Trees and Manifest Verification

* **Module Reader:** **[Module 5: Assertion Trees and Manifest Verification](./module-05/course.md)**
    1. [Assertion Trees](./module-05/course-01-assertion-trees.md)
    2. [Validating Signed Manifests](./module-05/course-02-validating-signed-manifests.md)
    3. [Summary](./module-05/course-03-summary.md)
* **Practice Lab Sandbox:** **`sections/section-010/module-05/labs/lab-01`** (`ats-011-lab-015`, UNTESTED)
* **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-010/module-05/labs/lab-01
    ```
* **Hands-on Objective:** Kyverno is installed. The namespace `assert-lab` exists and contains a service account named `app-sa`. Write a `ClusterPolicy` named `assert-pods` with `validationFailureAction: Enforce` and `background: false`. It needs one rule that uses `validate.assert` (not `pattern`) and matches Pods in the namespace `assert-lab`. The assertion tree must enforce all three requirements:
* **Free-Exploration Playground:** an ungraded sandbox with the same `kind` cluster and Kyverno already running, and no policies on it.
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-010/module-05/playground
    astrona destroy ats-011-playground-0105
    ```

### Capstone

* **Capstone Lab:** **`sections/section-010/capstone/labs/lab-01`** (`ats-011-lab-010`)
* **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-010/capstone/labs/lab-01
    ```

---

## Ready for Assessment?

Test your theoretical knowledge with the section quiz. It is a graded quiz with a pass score of 70 percent:

* **[Take the Section 010 Knowledge Check Quiz](./quiz.yaml)**
