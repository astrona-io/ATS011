# Image Signature & Attestation Verification

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS011/tree/main/sections/section-060/module-01/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS011.git -c sections/section-060/module-01/playground
> astrona destroy ats-011-playground-060
> ```

Every rule type covered so far in this course looks *inside* a resource — its labels, its containers, its resource limits — and reasons about the shape of the YAML itself. `verifyImages` is different: it reaches outside the cluster entirely, out to the OCI registry the image reference points at, and asks a question no amount of label-checking can answer — *did the organization we trust actually build and sign this exact image?*

That question matters because Kubernetes' admission model has no opinion about image provenance. `kubectl apply` a Pod running `evil.example.com/totally-legit-nginx:latest` and the API server pulls it and runs it with the same enthusiasm as an image your own CI pipeline built an hour ago. A compromised registry, a typosquatted image name, or a supply-chain attack that swaps a dependency mid-build all look identical to Kubernetes: just another image reference. `verifyImages` is Kyverno's answer — a rule type that checks a cryptographic signature (and optionally, signed metadata called attestations) before the Pod is ever admitted.

This module covers both halves of that story: verifying that an image is signed at all, and verifying that it carries specific attested facts about how it was built.

## How this module is organised

1. **[Part 1 — Signature Verification with verifyImages](./course-01-signature-verification-and-attestors.md)** — the `verifyImages` rule shape, `imageReferences` scoping, the `attestors` block, public-key vs. keyless verification, and what `failureAction` actually gates.
2. **[Part 2 — Attestations & Digest Pinning](./course-02-attestations-and-digest-pinning.md)** — verifying signed metadata (SBOMs, provenance, code review) beyond a bare signature, the `attestations` block and its `conditions`, and exactly how `mutateDigest` rewrites an image reference after a successful verification.

## Learning objectives

After this module you can:

- Explain what a `verifyImages` rule protects against that a `validate` rule cannot.
- Write `imageReferences` (and `skipImageReferences`) to scope a signature check to the images that actually need it.
- Configure an `attestors` block with a public key, including when a signature was produced without a matching Rekor transparency-log entry.
- Read and interpret Kyverno's image-verification failure messages, and know which webhook (`mutate` or `validate`) reports them.
- Write an `attestations` block that verifies a specific `predicateType` (or `type`, in current Kyverno) and inspects fields of the decoded predicate with `conditions`.
- Explain what `mutateDigest` actually does to a persisted Pod's image reference, and why that matters for supply-chain trust.

## Before you start

You should already be comfortable with `validate.pattern` and `foreach` (Section 010) — this module's capstone combines `verifyImages` with a `foreach` validate rule in one policy. No prior cryptography or Sigstore/Cosign experience is assumed; this module explains exactly as much of Cosign as you need to read and write a Kyverno policy around it.

The linked lab gives you a `kind` cluster with Kyverno already installed and running. You will write the `ClusterPolicy` yourself, then prove it against a real, publicly-hosted image that the Kyverno project maintains specifically for testing signature verification — no image signing infrastructure of your own required.

The **playground** linked at the top of this page gives you the same environment with nothing to submit: a single-node `kind` cluster with Kyverno v1.19.1 running and **no policies installed** (signature verification is done by Kyverno against the registry, so no local `cosign` install is needed — but the cluster does need outbound access to `ghcr.io`). Once it is up, `kubectl` is already pointed at it — the context is `kind-astro-ats-011-playground-060` (Astrona prefixes the environment name with `astro-`). The `Try it` checkpoints in the parts below assume that environment is already running; they never repeat the startup command.
