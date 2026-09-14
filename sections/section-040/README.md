# Section 040: Mutation Rules

Welcome to Section 040. Every rule you've written so far only ever answers yes or no — a `validate` rule accepts a resource as-is or rejects it, and it has no mechanism for changing anything about the object in front of it. That's a real gap: if every Pod is supposed to carry a `managed-by` label and a sane `imagePullPolicy`, rejecting every Pod that gets it wrong just pushes the fix back onto every developer, one `kubectl apply` at a time.

Kyverno's `mutate` rule closes that gap by rewriting the resource itself, before it's ever persisted. Instead of describing a shape a resource must already have, you describe a patch to apply — and Kyverno merges it in using Kubernetes' own strategic-merge-patch semantics, the same mechanism `kubectl apply` itself relies on.

---

## What You Will Master

By completing this section, you will acquire the two core competencies that separate "I can validate a resource" from "I can actually fix it":

* **patchStrategicMerge Mechanics:** How a `mutate.patchStrategicMerge` fragment merges into an incoming resource by list *key* rather than list *position*, the `(name)` anchor that makes a patch reach every element of a list, what really happens when the incoming resource already sets a conflicting value, and the hard guarantee that every mutate rule on the cluster finishes before any validate rule ever runs.
* **Mutating Existing Resources:** How `mutate.mutateExistingOnPolicyUpdate` and a `mutate.targets` block let a rule reach backward and patch resources that already existed before the policy did — triggered by the policy itself changing, not by a new admission request — the RBAC grant Kyverno insists on before it will even accept such a rule, and the real limits on what an already-existing resource can have changed on it.

---

## The Learning & Lab Path

This section has one module, paired with hands-on practice against a real `kind` cluster running Kyverno:

### 1. Mutation Rules

* **Module Reader:** **[Module 1: Mutation Rules](./module-01/course.md)**
    1. [patchStrategicMerge and Ordering](./module-01/course-01-patchstrategicmerge-mechanics.md)
    2. [Mutating Existing Resources](./module-01/course-02-mutating-existing-resources.md)
* **Practice Lab Sandbox:** **`sections/section-040/module-01/labs/lab-01`**
* **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-040/module-01/labs/lab-01
    ```
* **Hands-on Objective:** Write a `ClusterPolicy` with a `mutate.patchStrategicMerge` rule that injects a required label and a per-container default onto every Pod, then prove the persisted object actually carries both — including when a Pod arrives already setting conflicting values of its own.
* **Free-Exploration Playground:** an ungraded sandbox with the same `kind` cluster and Kyverno already running, and no policies on it — linked from the top of the module reader.
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-040/module-01/playground
    astrona destroy ats-011-playground-040
    ```

### 2. Per-Element Mutation and Idempotency

* **Module Reader:** **[Module 2: Per-Element Mutation and Idempotency](./module-02/course.md)**
    1. [foreach in a Mutate Rule](./module-02/course-01-foreach-in-mutate.md)
    2. [Idempotency and Rule Interaction](./module-02/course-02-idempotency-and-rule-interaction.md)
* **Free-Exploration Playground:** an ungraded sandbox with the same `kind` cluster and Kyverno already running, and no policies on it.
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-040/module-02/playground
    astrona destroy ats-011-playground-0402
    ```

---

## Ready for Assessment?

Test your theoretical knowledge and diagnostic reasoning before tackling the mutation rules lab mission:

* **[Take the Section 040 Knowledge Check Quiz](./quiz.md)**
