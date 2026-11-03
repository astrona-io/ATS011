# Section 050: Generation Rules

Welcome to Section 050. Every rule type covered so far reacts to a resource somebody else already tried to create — validation accepts or rejects it, a background scan reports on it after the fact. Kyverno's `generate` rule is the one exception: it *creates* a brand-new downstream resource on its own, in response to a trigger resource — classically a `Namespace` — coming into existence.

This is the mechanism behind a very common real-world platform pattern: "every namespace automatically gets a default-deny NetworkPolicy" or "every namespace automatically gets a copy of our shared CA bundle," guaranteed, without trusting every application team to remember to do it by hand.

---

## What You Will Master

By completing this section, you will acquire the two generation techniques every Kyverno policy author needs:

* **Data-Based Generation:** How to write a `generate` rule that targets `kind: Namespace` as its trigger, and produces a literal manifest (`generate.data`) — such as a default-deny `NetworkPolicy` — into every new namespace.
* **Clone-Based Generation & Synchronize:** How to copy an existing resource from a central source namespace (`generate.clone`) instead of writing it out by hand, and the exact, empirically-verified behavior of `synchronize: true` — what propagates from the source, what gets reverted if someone edits the clone directly, and what does (and does not) happen when the trigger namespace itself is deleted.
* **Cloning Several Resources and generate foreach:** How to use `cloneList` and `generate.foreach` to create many downstream resources.

---

## The Learning & Lab Path

Each module has a reader, a free-exploration playground and a graded lab. Every module ends with a summary page and a mission that points to its lab. The labs are marked UNTESTED until they have been run against a live cluster.

### 1. Generation Rules

* **Module Reader:** **[Module 1: Generation Rules](./module-01/course.md)**
    1. [Generating from Literal Data](./module-01/course-01-generate-rule-anatomy-and-data.md)
    2. [Cloning Resources and `synchronize`](./module-01/course-02-clone-and-synchronize.md)
    3. [Summary](./module-01/course-03-summary.md)
* **Practice Lab Sandbox:** **`sections/section-050/module-01/labs/lab-01`** (`ats-011-lab-051`, UNTESTED)
* **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-050/module-01/labs/lab-01
    ```
* **Hands-on Objective:** Solve this question against the `kind` cluster provisioned for this lab (Kyverno is already installed and running in the `kyverno` namespace).
* **Free-Exploration Playground:** an ungraded sandbox with the same `kind` cluster and Kyverno already running, and no policies on it.
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-050/module-01/playground
    astrona destroy ats-011-playground-050
    ```

### 2. Generating for What Already Exists

* **Module Reader:** **[Module 2: Generating for What Already Exists](./module-02/course.md)**
    1. [generateExisting and Retroactive Creation](./module-02/course-01-generate-existing.md)
    2. [Lifecycle — Policy Deletion and Orphaning](./module-02/course-02-lifecycle-and-orphaning.md)
    3. [Summary](./module-02/course-03-summary.md)
* **Practice Lab Sandbox:** **`sections/section-050/module-02/labs/lab-01`** (`ats-011-lab-052`, UNTESTED)
* **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-050/module-02/labs/lab-01
    ```
* **Hands-on Objective:** Kyverno is installed. The namespaces `team-a` and `team-b` already exist and are labelled `tier=standard`. The namespace `scratch` exists and has no `tier` label. The background controller is allowed to manage ConfigMaps.
* **Free-Exploration Playground:** an ungraded sandbox with the same `kind` cluster and Kyverno already running, and no policies on it.
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-050/module-02/playground
    astrona destroy ats-011-playground-0502
    ```

### 3. Cloning Several Resources and generate foreach

* **Module Reader:** **[Module 3: Cloning Several Resources and generate foreach](./module-03/course.md)**
    1. [cloneList: Cloning Many Sources](./module-03/course-01-clonelist.md)
    2. [generate foreach: One Resource per Element](./module-03/course-02-generate-foreach.md)
    3. [Summary](./module-03/course-03-summary.md)
* **Practice Lab Sandbox:** **`sections/section-050/module-03/labs/lab-01`** (`ats-011-lab-053`, UNTESTED)
* **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-050/module-03/labs/lab-01
    ```
* **Hands-on Objective:** Kyverno is installed. The namespace `shared-config` holds three ConfigMaps: `app-settings` and `feature-flags` are labelled `share=true`, and `private-notes` has no label. The background controller is allowed to manage ConfigMaps.
* **Free-Exploration Playground:** an ungraded sandbox with the same `kind` cluster and Kyverno already running, and no policies on it.
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-050/module-03/playground
    astrona destroy ats-011-playground-0503
    ```

### Capstone

* **Capstone Lab:** **`sections/section-050/capstone/labs/lab-01`** (`ats-011-lab-050`)
* **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-050/capstone/labs/lab-01
    ```

---

## Ready for Assessment?

Test your theoretical knowledge with the section quiz. It is a graded quiz with a pass score of 70 percent:

* **[Take the Section 050 Knowledge Check Quiz](./quiz.yaml)**
