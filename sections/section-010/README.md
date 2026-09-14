# Section 010: Validation Rules

Welcome to Section 010, the front door of the Writing Policies domain. Validation is where most people meet Kyverno for the first time: a `ClusterPolicy` that looks at incoming resources and either lets them through, rejects them, or just quietly logs the violation.

Kubernetes' built-in admission control gives you a binary choice — accept or reject a `kubectl apply` — but it has no opinion about *what a good resource looks like* inside your organization. Kyverno's `validate` rule fills that gap declaratively: instead of writing a webhook in Go, you describe the shape a resource must match, in YAML that looks almost like the resource itself.

---

## What You Will Master

By completing this section, you will acquire the two core competencies every Kyverno policy author needs first:

* **Pattern-Based Validation:** How to write a `ClusterPolicy` with a `validate.pattern` block, use wildcard operators (`?`, `*`) and conditional operators (`>`, `<=`, `!-`) inside a pattern, and choose between `Enforce` and `Audit` failure actions.
* **Multi-Path Validation:** How to accept more than one valid shape with `anyPattern`, iterate over list fields (like a Pod's `containers`) with `foreach`, and write messages that surface *why* a resource was rejected.

---

## The Learning & Lab Path

This section has one module, paired with hands-on practice against a real `kind` cluster running Kyverno:

### 1. Pattern-Based Validation

* **Module Reader:** **[Module 1: Pattern-Based Validation](./module-01/course.md)**
    1. [The ClusterPolicy Object and Its Audience](./module-01/course-01-the-clusterpolicy-object.md)
    2. [The Pattern Block and What Failure Costs](./module-01/course-02-the-pattern-block-and-failure-actions.md)
    3. [anyPattern, foreach & Failure Messages](./module-01/course-03-anypattern-foreach-and-messages.md)
* **Practice Lab Sandbox:** **`sections/section-010/module-01/labs/lab-01`**
* **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-010/module-01/labs/lab-01
    ```
* **Hands-on Objective:** Write a `ClusterPolicy` in `Enforce` mode that requires every Pod to carry a `team` label and sets CPU/memory limits on every container, then prove it blocks a non-compliant Pod and admits a compliant one.
* **Free-Exploration Playground:** an ungraded sandbox with the same `kind` cluster and Kyverno already running, and no policies on it — linked from the top of the module reader.
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-010/module-01/playground
    astrona destroy ats-011-playground-010
    ```

### 2. Deny Rules and the Condition Vocabulary

* **Module Reader:** **[Module 2: Deny Rules and the Condition Vocabulary](./module-02/course.md)**
    1. [Deny Rules and the Inversion](./module-02/course-01-deny-rules-and-the-inversion.md)
    2. [The Condition Operator Vocabulary](./module-02/course-02-condition-operator-vocabulary.md)
* **Free-Exploration Playground:** an ungraded sandbox with the same `kind` cluster and Kyverno already running, and no policies on it.
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-010/module-02/playground
    astrona destroy ats-011-playground-0102
    ```

### 3. Validation Anchors

* **Module Reader:** **[Module 3: Validation Anchors](./module-03/course.md)**
    1. [Conditional and Equality Anchors](./module-03/course-01-conditional-and-equality-anchors.md)
    2. [Existence, Negation, and Global Anchors](./module-03/course-02-existence-negation-and-global-anchors.md)
* **Free-Exploration Playground:** an ungraded sandbox with the same `kind` cluster and Kyverno already running, and no policies on it.
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-010/module-03/playground
    astrona destroy ats-011-playground-0103
    ```

### 4. The podSecurity Subrule

* **Module Reader:** **[Module 4: The podSecurity Subrule](./module-04/course.md)**
    1. [Profiles, Levels, and Versions](./module-04/course-01-podsecurity-profiles-and-levels.md)
    2. [Excluding Controls, and PSS Versus PSA](./module-04/course-02-excluding-controls-and-psa.md)
* **Free-Exploration Playground:** an ungraded sandbox with the same `kind` cluster and Kyverno already running, and no policies on it.
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-010/module-04/playground
    astrona destroy ats-011-playground-0104
    ```

---

## Ready for Assessment?

Test your theoretical knowledge and diagnostic reasoning before tackling the validation lab mission:

* **[Take the Section 010 Knowledge Check Quiz](./quiz.md)**
