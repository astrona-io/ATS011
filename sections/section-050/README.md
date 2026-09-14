# Section 050: Generation Rules

Welcome to Section 050. Every rule type covered so far reacts to a resource somebody else already tried to create — validation accepts or rejects it, a background scan reports on it after the fact. Kyverno's `generate` rule is the one exception: it *creates* a brand-new downstream resource on its own, in response to a trigger resource — classically a `Namespace` — coming into existence.

This is the mechanism behind a very common real-world platform pattern: "every namespace automatically gets a default-deny NetworkPolicy" or "every namespace automatically gets a copy of our shared CA bundle," guaranteed, without trusting every application team to remember to do it by hand.

---

## What You Will Master

By completing this section, you will acquire the two generation techniques every Kyverno policy author needs:

* **Data-Based Generation:** How to write a `generate` rule that targets `kind: Namespace` as its trigger, and produces a literal manifest (`generate.data`) — such as a default-deny `NetworkPolicy` — into every new namespace.
* **Clone-Based Generation & Synchronize:** How to copy an existing resource from a central source namespace (`generate.clone`) instead of writing it out by hand, and the exact, empirically-verified behavior of `synchronize: true` — what propagates from the source, what gets reverted if someone edits the clone directly, and what does (and does not) happen when the trigger namespace itself is deleted.

---

## The Learning & Lab Path

This section has one module, paired with hands-on practice against a real `kind` cluster running Kyverno:

### 1. Data-Based Generation

* **Module Reader:** **[Module 1: Generation Rules](./module-01/course.md)**
    1. [Generating from Literal Data](./module-01/course-01-generate-rule-anatomy-and-data.md)
    2. [Cloning Resources and synchronize](./module-01/course-02-clone-and-synchronize.md)
* **Practice Lab Sandbox:** **`sections/section-050/module-01/labs/lab-01`**
* **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-050/module-01/labs/lab-01
    ```
* **Hands-on Objective:** Write a `ClusterPolicy` with a `generate` rule that fires on Namespace creation and produces a default-deny `NetworkPolicy`, with exact literal content, into every new namespace — then prove it against a Namespace you create yourself.
* **Free-Exploration Playground:** an ungraded sandbox with the same `kind` cluster and Kyverno already running, and no policies on it — linked from the top of the module reader.
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-050/module-01/playground
    astrona destroy ats-011-playground-050
    ```

### 2. Generating for What Already Exists

* **Module Reader:** **[Module 2: Generating for What Already Exists](./module-02/course.md)**
    1. [generateExisting and Retroactive Creation](./module-02/course-01-generate-existing.md)
    2. [Lifecycle: Policy Deletion and Orphaning](./module-02/course-02-lifecycle-and-orphaning.md)
* **Free-Exploration Playground:** an ungraded sandbox with the same `kind` cluster and Kyverno already running, and no policies on it.
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-050/module-02/playground
    astrona destroy ats-011-playground-0502
    ```

---

## Ready for Assessment?

Test your theoretical knowledge and diagnostic reasoning before tackling the generation lab mission:

* **[Take the Section 050 Knowledge Check Quiz](./quiz.md)**
