# Section 080: JSON Patches

`patchStrategicMerge` — the mutation style you met in Section 040 — works by describing the *shape* you want and letting Kubernetes' strategic-merge logic reconcile it with the resource. That is comfortable and declarative, and it is also the reason it sometimes can't express what you need. Strategic merge has no way to say "remove this key," no way to address "the first container specifically," and no way to say "append to the end of this list" without pulling in a merge key. For those jobs Kyverno offers a second, lower-level mutation vocabulary: **`patchesJson6902`** — RFC 6902 JSON Patch.

A JSON Patch is not a shape. It is an ordered list of *operations* — `add`, `remove`, `replace`, `copy`, `move`, `test` — each aimed at an exact location in the document via an RFC 6901 JSON Pointer. It is more explicit, more surgical, and considerably less forgiving: a path that doesn't resolve can reject the entire admission request rather than quietly doing nothing. That trade — precision in exchange for strictness — is what this section is about, and the KCA expects you to know which operations behave leniently, which do not, and how to write a patch that is safe regardless.

---

## What You Will Master

By completing this section, you will acquire the two core competencies every Kyverno policy author needs around JSON Patches:

* **Writing RFC 6902 Operations:** How to author a `mutate.patchesJson6902` rule, address an exact array element or the append position with a JSON Pointer path, and choose the right operation for the job — including why `add` against an existing key replaces rather than errors, and why `/env/-` works even when the container has no `env` array at all.
* **Paths, Escaping, and Safe Removal:** How to escape a literal `/` inside an annotation or label key as `~1` in a JSON Pointer, how `remove` and `replace` differ when the target path is missing, and how to guard a destructive operation with a `preconditions` block so the rule behaves the same way on every Kyverno version instead of depending on one version's leniency.

---

## The Learning & Lab Path

Each module has a reader, a free-exploration playground and a graded lab. Every module ends with a summary page and a mission that points to its lab. The labs are marked UNTESTED until they have been run against a live cluster.

### 1. JSON Patches

* **Module Reader:** **[Module 1: JSON Patches](./module-01/course.md)**
    1. [RFC 6902 Operations and Pointer Paths](./module-01/course-01-json-patch-operations.md)
    2. [Pointer Escaping and Missing Paths](./module-01/course-02-pointer-escaping-and-missing-paths.md)
    3. [Guarded Removal and Safe Patch Design](./module-01/course-03-guarded-removal-and-safe-patches.md)
    4. [Summary](./module-01/course-04-summary.md)
* **Practice Lab Sandbox:** **`sections/section-080/module-01/labs/lab-01`** (`ats-011-lab-081`, UNTESTED)
* **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-080/module-01/labs/lab-01
    ```
* **Hands-on Objective:** Solve this question against the `kind` cluster provisioned for this lab (Kyverno is already installed and running in the `kyverno` namespace).
* **Free-Exploration Playground:** an ungraded sandbox with the same `kind` cluster and Kyverno already running, and no policies on it.
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-080/module-01/playground
    astrona destroy ats-011-playground-080
    ```

### Capstone

* **Capstone Lab:** **`sections/section-080/capstone/labs/lab-01`** (`ats-011-lab-080`)
* **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-080/capstone/labs/lab-01
    ```

---

## Ready for Assessment?

Test your theoretical knowledge with the section quiz. It is a graded quiz with a pass score of 70 percent:

* **[Take the Section 080 Knowledge Check Quiz](./quiz.yaml)**
