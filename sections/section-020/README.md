# Section 020: Preconditions

Welcome to Section 020. Section 010 gave you two levers for a validate rule: `match`/`exclude` to choose an audience, and `validate.pattern` to define a shape. Real policies almost always need a third lever, because "check this shape" and "except when…" are different questions — and the exception is often something `match`'s structural vocabulary (kind, namespace, label, name) simply cannot express on its own.

`preconditions` is that third lever: a block that evaluates `any`/`all` lists of `{key, operator, value}` conditions against the live admission request — the incoming resource's own field values, the verb being performed, variables — and decides whether the rule body even runs for a resource that already passed `match`. Get this wrong and you either enforce a rule where you meant to exempt something, or silently skip a check you meant to run.

---

## What You Will Master

By completing this section, you will acquire the core competency for writing precondition-gated rules:

* **The Preconditions Block:** How to write `preconditions.all`/`any`, the full operator vocabulary (`Equals`, `NotEquals`, the `AnyIn`/`AllIn`/`AnyNotIn`/`AllNotIn` set operators, numeric and duration comparisons), and how to reference `request.operation` and resource fields inside a condition's `key`.
* **Preconditions vs. match/exclude:** Where the two tools' capabilities genuinely overlap, where `match`/`exclude`'s static-only restriction (no `{{ }}` variables, ever) forces you into `preconditions` instead, and the behavioral difference between `all` (AND) and `any` (OR).

---

## The Learning & Lab Path

Each module has a reader, a free-exploration playground and a graded lab. Every module ends with a summary page and a mission that points to its lab. The labs are marked UNTESTED until they have been run against a live cluster.

### 1. Preconditions

* **Module Reader:** **[Module 1: Preconditions](./module-01/course.md)**
    1. [The Preconditions Block and Its Operators](./module-01/course-01-preconditions-and-operators.md)
    2. [Preconditions vs. match/exclude, and all vs. any](./module-01/course-02-preconditions-vs-match.md)
    3. [Summary](./module-01/course-03-summary.md)
* **Practice Lab Sandbox:** **`sections/section-020/module-01/labs/lab-01`** (`ats-011-lab-021`, UNTESTED)
* **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-020/module-01/labs/lab-01
    ```
* **Hands-on Objective:** Solve this question against the `kind` cluster provisioned for this lab (Kyverno is already installed and running in the `kyverno` namespace).
* **Free-Exploration Playground:** an ungraded sandbox with the same `kind` cluster and Kyverno already running, and no policies on it.
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-020/module-01/playground
    astrona destroy ats-011-playground-020
    ```

### Capstone

* **Capstone Lab:** **`sections/section-020/capstone/labs/lab-01`** (`ats-011-lab-020`)
* **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-020/capstone/labs/lab-01
    ```

---

## Ready for Assessment?

Test your theoretical knowledge with the section quiz. It is a graded quiz with a pass score of 70 percent:

* **[Take the Section 020 Knowledge Check Quiz](./quiz.yaml)**
