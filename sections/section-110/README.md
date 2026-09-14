# Section 110: Common Expression Language (CEL)

Every policy in the previous ten sections describes a *shape*. A `validate.pattern` block is a fragment of YAML with wildcards and anchors, matched structurally against the resource. It is declarative, it is readable, and it runs out of road the moment your requirement is a computation rather than a shape — "every container's memory limit must be under 2Gi", "the `replicas` field may only ever increase", "at least one of these three labels must be present."

**CEL — the Common Expression Language — is Kubernetes' own answer to that.** It is the same small, sandboxed, non-Turing-complete expression language the API server uses for CRD validation rules and for `ValidatingAdmissionPolicy`. Kyverno exposes it in two distinct places, and the difference between them matters: as a `validate.cel` block inside the `ClusterPolicy` you already know, and as a whole new family of policy types — `ValidatingPolicy` and its siblings in the `policies.kyverno.io` API group — where CEL is not an alternative syntax but the only one.

The second of those is where the deprecation warnings you have been ignoring since Section 010 have been pointing all along. This section is where they get answered.

There is a further twist worth knowing before you start: because CEL policies speak the API server's native dialect, Kyverno can compile one into a real Kubernetes `ValidatingAdmissionPolicy` and step out of the request path entirely — enforcement moves from Kyverno's webhook into the API server itself. You can watch the rejection message change shape when it happens.

---

## What You Will Master

By completing this section, you will acquire the two core competencies every Kyverno policy author needs around CEL:

* **Writing CEL Validations Inside a ClusterPolicy:** How to replace a `validate.pattern` with a `validate.cel` block, read and write expressions over `object`, `oldObject`, and `request`, use the CEL macros that matter for Kubernetes resources (`has()`, `all()`, `exists()`, `size()`), factor repeated sub-expressions into `variables`, and understand why a CEL expression states what must be **true** rather than what the resource must **look like**.
* **The CEL-Native Policy Types:** How to write a `ValidatingPolicy` with `matchConstraints`, `validations`, and `validationActions`, pre-filter requests with `matchConditions`, choose `Deny` versus `Audit`, recognise the autogen behaviour that carries over from Section 090, and generate a native Kubernetes `ValidatingAdmissionPolicy` — including identifying, from the rejection message alone, which of the three enforcement paths actually blocked a request.

---

## The Learning & Lab Path

This section has one module, paired with hands-on practice against a real `kind` cluster running Kyverno:

### 1. CEL in Kyverno Policies

* **Module Reader:** **[Module 1: CEL in Kyverno Policies](./module-01/course.md)**
    1. [CEL as a Language](./module-01/course-01-cel-as-a-language.md)
    2. [Writing a validate.cel Rule Safely](./module-01/course-02-writing-validate-cel-safely.md)
    3. [The ValidatingPolicy Type](./module-01/course-03-the-validatingpolicy-type.md)
    4. [Autogen and Native Admission Policies](./module-01/course-04-autogen-and-native-admission-policies.md)
* **Practice Lab Sandbox:** **`sections/section-110/module-01/labs/lab-01`**
* **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-110/module-01/labs/lab-01
    ```
* **Hands-on Objective:** Write a `ClusterPolicy` whose rule validates with a `validate.cel` expression — not a `pattern` — requiring every container in every Pod to set a memory limit, and prove it rejects a Pod whose second container forgot one.
* **Free-Exploration Playground:** an ungraded sandbox with the same `kind` cluster and Kyverno already running, and no policies on it — linked from the top of the module reader.
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-110/module-01/playground
    astrona destroy ats-011-playground-110
    ```

---

## Ready for Assessment?

Test your theoretical knowledge and diagnostic reasoning before tackling the CEL lab mission:

* **[Take the Section 110 Knowledge Check Quiz](./quiz.md)**
