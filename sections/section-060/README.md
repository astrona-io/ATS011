# Section 060: VerifyImage Rules

Welcome to Section 060. Every rule type covered so far looks *inside* a resource — its labels, its containers, its resource limits — and reasons about the YAML in front of it. Kyverno's `verifyImages` rule is different: it reaches out to the OCI registry the image reference points at and asks a question no amount of label-checking can answer — *did the organization we trust actually build and sign this exact image?*

Kubernetes has no native opinion about image provenance. `kubectl apply` a Pod running any image reference, from any registry, and the API server pulls and runs it with equal enthusiasm. A compromised registry, a typosquatted image name, or a supply-chain attack that swaps a dependency mid-build all look identical to the cluster: just another image reference. `verifyImages` closes that gap by requiring a real cryptographic signature — and optionally, signed metadata called attestations — before a Pod is ever admitted.

---

## What You Will Master

By completing this section, you will acquire the two core competencies every Kyverno policy author needs for supply-chain trust:

* **Signature Verification with verifyImages:** How to write a `verifyImages` rule scoped with `imageReferences`, configure an `attestors` block with a public key (including the transparency-log wrinkle real signed demo images can hit), and choose `Enforce` at the rule level to block an unsigned or wrongly-signed image outright.
* **Attestations & Digest Pinning:** How to verify signed metadata beyond a bare signature — SBOMs, build provenance, code review — with an `attestations` block and its `conditions`, and the exact, empirically-verified behavior of `mutateDigest`: how Kyverno rewrites an admitted Pod's image reference to pin the precise digest that was just verified.

---

## The Learning & Lab Path

This section has one module, paired with hands-on practice against a real `kind` cluster running Kyverno:

### 1. Image Signature & Attestation Verification

* **Module Reader:** **[Module 1: Image Signature & Attestation Verification](./module-01/course.md)**
    1. [Signature Verification with verifyImages](./module-01/course-01-signature-verification-and-attestors.md)
    2. [Attestations & Digest Pinning](./module-01/course-02-attestations-and-digest-pinning.md)
* **Practice Lab Sandbox:** **`sections/section-060/module-01/labs/lab-01`**
* **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-060/module-01/labs/lab-01
    ```
* **Hands-on Objective:** Write a `ClusterPolicy` with a `verifyImages` rule requiring a real Cosign signature from a specific public key, scoped to a real, permanently-hosted demo image repository, then prove it against a correctly-signed image, an unsigned image, and an image signed with the wrong key.
* **Free-Exploration Playground:** an ungraded sandbox with the same `kind` cluster and Kyverno already running, and no policies on it — linked from the top of the module reader.
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-060/module-01/playground
    astrona destroy ats-011-playground-060
    ```

### 2. Attestors, Digests, and Registry Access

* **Module Reader:** **[Module 2: Attestors, Digests, and Registry Access](./module-02/course.md)**
    1. [Attestor Structures and Trust Material](./module-02/course-01-attestor-structures.md)
    2. [Digests, Scope, and Registry Access](./module-02/course-02-digests-scope-and-registry-access.md)
* **Free-Exploration Playground:** an ungraded sandbox with the same `kind` cluster and Kyverno already running, and no policies on it.
    ```bash
    astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-060/module-02/playground
    astrona destroy ats-011-playground-0602
    ```

---

## Ready for Assessment?

Test your theoretical knowledge and diagnostic reasoning before tackling the image verification lab mission:

* **[Take the Section 060 Knowledge Check Quiz](./quiz.md)**
