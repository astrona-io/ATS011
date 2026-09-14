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

This section has one module, paired with hands-on practice against a real `kind` cluster running Kyverno:

### 1. The Preconditions Block

* **Module Reader:** **[Module 1: Preconditions](./module-01/course.md)**
    1. [The Preconditions Block and Its Operators](./module-01/course-01-preconditions-and-operators.md)
    2. [Preconditions vs. match/exclude, and all vs. any](./module-01/course-02-preconditions-vs-match.md)
* **Practice Lab Sandbox:** **`sections/section-020/module-01/labs/lab-01`**
* **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-020/module-01/labs/lab-01
    ```
* **Hands-on Objective:** Write a `ClusterPolicy` that requires every Pod to carry a `team` label, but uses a `preconditions` block — not `match`/`exclude` — to skip that check for Pods carrying an exemption signal, then prove the exemption really skips the rule rather than just satisfying it.
* **Free-Exploration Playground:** an ungraded sandbox with the same `kind` cluster and Kyverno already running, and no policies on it — linked from the top of the module reader.
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-020/module-01/playground
    astrona destroy ats-011-playground-020
    ```

---

## Ready for Assessment?

Test your theoretical knowledge and diagnostic reasoning before tackling the preconditions lab mission:

* **[Take the Section 020 Knowledge Check Quiz](./quiz.md)**
