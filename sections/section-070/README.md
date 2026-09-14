# Section 070: Variables & API Calls in Policies

Every policy up to this point has been static: patterns, preconditions, and mutations that all compare an incoming resource against values you typed directly into the YAML. This section is where Kyverno policies stop being purely declarative snapshots and start reacting to *live cluster state* — the exact skill the KCA exam tests when it asks you to write a rule whose decision genuinely cannot be made just by reading the resource in front of it.

`{{ }}` variables and JMESPath let a rule reach into the admission request — the resource, its previous version on an UPDATE, who's making the request. `context.apiCall` goes further: it lets a rule fetch fresh data from the Kubernetes API (or any HTTP JSON service) and fold the result into the decision, at the exact moment the rule runs.

---

## What You Will Master

By completing this section, you will acquire the two core competencies of Kyverno's dynamic-data toolkit:

* **Variables & JMESPath:** The `{{ }}` syntax and exactly where it is (and categorically isn't) legal, JMESPath basics as Kyverno uses them, and the built-in request variables (`request.object`, `request.oldObject`, `request.operation`, `request.userInfo`) every real policy eventually needs.
* **context.apiCall:** The rule-level `context` block that calls the Kubernetes API at evaluation time, the exact field shape (`urlPath`, `jmesPath`, `method`, `data`, `service`, `default`), and — verified against a live cluster, not assumed — what happens when the API call itself fails.

---

## The Learning & Lab Path

This section has one module, paired with hands-on practice against a real `kind` cluster running Kyverno:

### 1. Variables & API Calls in Policies

* **Module Reader:** **[Module 1: Variables & API Calls in Policies](./module-01/course.md)**
    1. [JMESPath, Variables & Built-in Context](./module-01/course-01-jmespath-variables-and-context.md)
    2. [context.apiCall & Live Cluster Data](./module-01/course-02-apicall-and-live-cluster-data.md)
* **Practice Lab Sandbox:** **`sections/section-070/module-01/labs/lab-01`**
* **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-070/module-01/labs/lab-01
    ```
* **Hands-on Objective:** Write a `ClusterPolicy` that uses `context.apiCall` to count the Pods that already exist in a namespace, live, at admission time, and denies a new Pod once that namespace hits a 3-Pod limit — a real quota decision built from data the policy does not and cannot hardcode.
* **Free-Exploration Playground:** an ungraded sandbox with the same `kind` cluster and Kyverno already running, and no policies on it — linked from the top of the module reader.
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-070/module-01/playground
    astrona destroy ats-011-playground-070
    ```

### 2. Context Beyond apiCall

* **Module Reader:** **[Module 2: Context Beyond apiCall](./module-02/course.md)**
    1. [configMap and variable](./module-02/course-01-configmap-and-variable-context.md)
    2. [imageRegistry and globalReference](./module-02/course-02-imageregistry-and-globalreference.md)
* **Free-Exploration Playground:** an ungraded sandbox with the same `kind` cluster and Kyverno already running, and no policies on it.
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-070/module-02/playground
    astrona destroy ats-011-playground-0702
    ```

---

## Ready for Assessment?

Test your theoretical knowledge and diagnostic reasoning before tackling the variables-and-apiCall lab mission:

* **[Take the Section 070 Knowledge Check Quiz](./quiz.md)**
