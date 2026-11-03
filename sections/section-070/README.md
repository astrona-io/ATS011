# Section 070: Variables & API Calls in Policies

Every policy up to this point has been static: patterns, preconditions, and mutations that all compare an incoming resource against values you typed directly into the YAML. This section is where Kyverno policies stop being purely declarative snapshots and start reacting to *live cluster state* — the exact skill the KCA exam tests when it asks you to write a rule whose decision genuinely cannot be made just by reading the resource in front of it.

`{{ }}` variables and JMESPath let a rule reach into the admission request — the resource, its previous version on an UPDATE, who's making the request. `context.apiCall` goes further: it lets a rule fetch fresh data from the Kubernetes API (or any HTTP JSON service) and fold the result into the decision, at the exact moment the rule runs.

---

## What You Will Master

By completing this section, you will acquire the two core competencies of Kyverno's dynamic-data toolkit:

* **Variables & JMESPath:** The `{{ }}` syntax and exactly where it is (and categorically isn't) legal, JMESPath basics as Kyverno uses them, and the built-in request variables (`request.object`, `request.oldObject`, `request.operation`, `request.userInfo`) every real policy eventually needs.
* **context.apiCall:** The rule-level `context` block that calls the Kubernetes API at evaluation time, the exact field shape (`urlPath`, `jmesPath`, `method`, `data`, `service`, `default`), and — verified against a live cluster, not assumed — what happens when the API call itself fails.
* **The Kyverno JMESPath Function Library:** How to use the custom JMESPath functions for strings, numbers, collections, time and encoding.

---

## The Learning & Lab Path

Each module has a reader, a free-exploration playground and a graded lab. Every module ends with a summary page and a mission that points to its lab. The labs are marked UNTESTED until they have been run against a live cluster.

### 1. Variables & API Calls in Policies

* **Module Reader:** **[Module 1: Variables & API Calls in Policies](./module-01/course.md)**
    1. [JMESPath, Variables & Built-in Context](./module-01/course-01-jmespath-variables-and-context.md)
    2. [context.apiCall & Live Cluster Data](./module-01/course-02-apicall-and-live-cluster-data.md)
    3. [Summary](./module-01/course-03-summary.md)
* **Practice Lab Sandbox:** **`sections/section-070/module-01/labs/lab-01`** (`ats-011-lab-071`, UNTESTED)
* **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-070/module-01/labs/lab-01
    ```
* **Hands-on Objective:** Solve this question against the `kind` cluster provisioned for this lab (Kyverno is already installed and running in the `kyverno` namespace). The namespace `team-a` already exists and already has **two** Pods running in it before you write anything — that's deliberate, so you can prove your policy reacts to real, live cluster state.
* **Free-Exploration Playground:** an ungraded sandbox with the same `kind` cluster and Kyverno already running, and no policies on it.
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-070/module-01/playground
    astrona destroy ats-011-playground-070
    ```

### 2. Context Beyond apiCall

* **Module Reader:** **[Module 2: Context Beyond apiCall](./module-02/course.md)**
    1. [configMap and variable](./module-02/course-01-configmap-and-variable-context.md)
    2. [imageRegistry and globalReference](./module-02/course-02-imageregistry-and-globalreference.md)
    3. [Summary](./module-02/course-03-summary.md)
* **Practice Lab Sandbox:** **`sections/section-070/module-02/labs/lab-01`** (`ats-011-lab-072`, UNTESTED)
* **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-070/module-02/labs/lab-01
    ```
* **Hands-on Objective:** Kyverno is installed. The ConfigMap `limits` in the namespace `policy-config` has the key `max-replicas` with the value `3`. The namespace `ctx-lab` exists.
* **Free-Exploration Playground:** an ungraded sandbox with the same `kind` cluster and Kyverno already running, and no policies on it.
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-070/module-02/playground
    astrona destroy ats-011-playground-0702
    ```

### 3. The Kyverno JMESPath Function Library

* **Module Reader:** **[Module 3: The Kyverno JMESPath Function Library](./module-03/course.md)**
    1. [String and number functions](./module-03/course-01-string-and-number-functions.md)
    2. [Collections, time and encoding functions](./module-03/course-02-collections-time-and-encoding-functions.md)
    3. [Summary](./module-03/course-03-summary.md)
* **Practice Lab Sandbox:** **`sections/section-070/module-03/labs/lab-01`** (`ats-011-lab-073`, UNTESTED)
* **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-070/module-03/labs/lab-01
    ```
* **Hands-on Objective:** Kyverno is installed and the namespace `fn-lab` exists. Pods in that namespace must carry annotations that describe who owns them and how they were approved.
* **Free-Exploration Playground:** an ungraded sandbox with the same `kind` cluster and Kyverno already running, and no policies on it.
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-070/module-03/playground
    astrona destroy ats-011-playground-0703
    ```

### Capstone

* **Capstone Lab:** **`sections/section-070/capstone/labs/lab-01`** (`ats-011-lab-070`)
* **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-070/capstone/labs/lab-01
    ```

---

## Ready for Assessment?

Test your theoretical knowledge with the section quiz. It is a graded quiz with a pass score of 70 percent:

* **[Take the Section 070 Knowledge Check Quiz](./quiz.yaml)**
