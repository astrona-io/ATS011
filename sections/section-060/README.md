# Section 060: VerifyImage Rules

Welcome to Section 060. Every rule type covered so far looks *inside* a resource — its labels, its containers, its resource limits — and reasons about the YAML in front of it. Kyverno's `verifyImages` rule is different: it reaches out to the OCI registry the image reference points at and asks a question no amount of label-checking can answer — *did the organization we trust actually build and sign this exact image?*

Kubernetes has no native opinion about image provenance. `kubectl apply` a Pod running any image reference, from any registry, and the API server pulls and runs it with equal enthusiasm. A compromised registry, a typosquatted image name, or a supply-chain attack that swaps a dependency mid-build all look identical to the cluster: just another image reference. `verifyImages` closes that gap by requiring a real cryptographic signature — and optionally, signed metadata called attestations — before a Pod is ever admitted.

---

## What You Will Master

By completing this section, you will acquire the two core competencies every Kyverno policy author needs for supply-chain trust:

* **Signature Verification with verifyImages:** How to write a `verifyImages` rule scoped with `imageReferences`, configure an `attestors` block with a public key (including the transparency-log wrinkle real signed demo images can hit), and choose `Enforce` at the rule level to block an unsigned or wrongly-signed image outright.
* **Attestations & Digest Pinning:** How to verify signed metadata beyond a bare signature — SBOMs, build provenance, code review — with an `attestations` block and its `conditions`, and the exact, empirically-verified behavior of `mutateDigest`: how Kyverno rewrites an admitted Pod's image reference to pin the precise digest that was just verified.
* **The images Variable and Image Extraction:** How to query the `images` variable and use `imageExtractors` for custom resources.

---

## The Learning & Lab Path

Each module has a reader, a free-exploration playground and a graded lab. Every module ends with a summary page and a mission that points to its lab. The labs are marked UNTESTED until they have been run against a live cluster.

### 1. Image Signature & Attestation Verification

* **Module Reader:** **[Module 1: Image Signature & Attestation Verification](./module-01/course.md)**
    1. [Signature Verification with verifyImages](./module-01/course-01-signature-verification-and-attestors.md)
    2. [Attestations & Digest Pinning](./module-01/course-02-attestations-and-digest-pinning.md)
    3. [Summary](./module-01/course-03-summary.md)
* **Practice Lab Sandbox:** **`sections/section-060/module-01/labs/lab-01`** (`ats-011-lab-061`, UNTESTED)
* **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-060/module-01/labs/lab-01
    ```
* **Hands-on Objective:** Solve this question against the `kind` cluster provisioned for this lab (Kyverno is already installed and running in the `kyverno` namespace).
* **Free-Exploration Playground:** an ungraded sandbox with the same `kind` cluster and Kyverno already running, and no policies on it.
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-060/module-01/playground
    astrona destroy ats-011-playground-060
    ```

### 2. Attestors, Digests, and Registry Access

* **Module Reader:** **[Module 2: Attestors, Digests, and Registry Access](./module-02/course.md)**
    1. [Attestor Structures and Trust Material](./module-02/course-01-attestor-structures.md)
    2. [Digests, Scope, and Registry Access](./module-02/course-02-digests-scope-and-registry-access.md)
    3. [Summary](./module-02/course-03-summary.md)
* **Practice Lab Sandbox:** **`sections/section-060/module-02/labs/lab-01`** (`ats-011-lab-062`, UNTESTED)
* **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-060/module-02/labs/lab-01
    ```
* **Hands-on Objective:** Kyverno is installed and the namespace `verify-lab` exists. Write a `ClusterPolicy` named `verify-release-images` with `validationFailureAction: Enforce` and `background: false` that contains one `verifyImages` rule for Pods in `verify-lab`:
* **Free-Exploration Playground:** an ungraded sandbox with the same `kind` cluster and Kyverno already running, and no policies on it.
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-060/module-02/playground
    astrona destroy ats-011-playground-0602
    ```

### 3. The images Variable and Image Extraction

* **Module Reader:** **[Module 3: The images Variable and Image Extraction](./module-03/course.md)**
    1. [The images Variable](./module-03/course-01-the-images-variable.md)
    2. [Image Extractors](./module-03/course-02-image-extractors.md)
    3. [Summary](./module-03/course-03-summary.md)
* **Practice Lab Sandbox:** **`sections/section-060/module-03/labs/lab-01`** (`ats-011-lab-063`, UNTESTED)
* **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-060/module-03/labs/lab-01
    ```
* **Hands-on Objective:** Kyverno is installed and the namespace `image-lab` exists. Write a `ClusterPolicy` named `image-source-rules` with `validationFailureAction: Enforce` and `background: false`. It must contain two rules that match Pods in `image-lab`, and both must use the `images` context variable:
* **Free-Exploration Playground:** an ungraded sandbox with the same `kind` cluster and Kyverno already running, and no policies on it.
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-060/module-03/playground
    astrona destroy ats-011-playground-0603
    ```

### Capstone

* **Capstone Lab:** **`sections/section-060/capstone/labs/lab-01`** (`ats-011-lab-060`)
* **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-060/capstone/labs/lab-01
    ```

---

## Ready for Assessment?

Test your theoretical knowledge with the section quiz. It is a graded quiz with a pass score of 70 percent:

* **[Take the Section 060 Knowledge Check Quiz](./quiz.yaml)**
