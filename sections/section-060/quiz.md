# Section 060 Knowledge Check: VerifyImage Rules

Test your diagnostic reasoning before attempting the lab. Try to answer each question yourself before expanding the explanation.

---

**1.** You write a `ClusterPolicy` with a `verifyImages` rule, but set `imageReferences: ['*']` so you "don't have to think about scoping." You apply it in `Enforce` mode to a live cluster. What happens?

<details>
<summary>Show Answer</summary>

Almost certainly a cluster-wide outage. `imageReferences: ['*']` verifies *every* image the cluster ever pulls — including Kyverno's own controller images, `kube-proxy`, CoreDNS, and every application image already running — against the single set of attestors you configured. None of those are signed with that key, so nearly every future Pod admission (and every rolling update of an existing Deployment) gets rejected. `imageReferences` should always be scoped to the specific repository or repositories your signing requirement actually covers.
</details>

---

**2.** A `verifyImages` rule fails to admit a Pod. You check `kubectl describe` and see the denial came from a webhook named `mutate.kyverno.svc-fail`, not a validating webhook. Is that a bug?

<details>
<summary>Show Answer</summary>

No — that's expected. `verifyImages` is implemented inside Kyverno's *mutating* admission webhook, because a successful verification also needs to mutate the image reference to pin its digest (see `mutateDigest`). A failed verification simply denies the request from within that same mutating call instead of returning a patch. If you're hunting for `verifyImages` failures in webhook logs, look under the mutating webhook, not the validating one.
</details>

---

**3.** You sign an image offline with Cosign, without uploading to the public Rekor transparency log. You write a `verifyImages` rule with an `attestors.entries[].keys` block pointing at the correct public key, but omit any `rekor` configuration. Does the correctly-signed image get admitted?

<details>
<summary>Show Answer</summary>

No, not with Kyverno's default behavior. Kyverno's default is to cross-check the signature against Rekor as part of verification, and since this signature has no matching transparency-log entry, verification fails even though the cryptographic signature itself is completely valid. Setting `rekor.ignoreTlog: true` on the attestor tells Kyverno to skip that cross-check and trust the public-key verification alone — which is what a signature produced without a Rekor upload requires.
</details>

---

**4.** True or false: a single `verifyImages` entry can require both a valid image signature *and* a valid attestation of a specific predicate type.

<details>
<summary>Show Answer</summary>

False. Kyverno's documentation is explicit: each `verifyImages` entry verifies signatures *or* attestations, not both. If you need to enforce both requirements on the same image family, you write two separate `verifyImages` entries (or two separate rules) — one with a top-level `attestors` block for the signature, one with an `attestations` block (which has its own, separately-configured `attestors`) for the attestation.
</details>

---

**5.** A Pod runs `ghcr.io/kyverno/test-verify-image:signed` and is admitted by a `verifyImages` rule with the default `mutateDigest` behavior. What does `kubectl get pod <name> -o jsonpath='{.spec.containers[0].image}'` show?

<details>
<summary>Show Answer</summary>

Something like `ghcr.io/kyverno/test-verify-image:signed@sha256:b31bfb4d...` — both the original tag *and* the resolved digest, combined. `mutateDigest: true` does not strip the tag and replace it with a bare digest; it appends the digest onto the existing reference. The digest is authoritative when both are present, so the Pod is fully pinned to the exact verified bytes, immune to a later re-push under the same tag.
</details>

---

**6.** You verify an image attestation produced with a recent version of Cosign, using a plain `attestations[].attestors[].keys` block (no `type` field at the `verifyImages` entry level). Kyverno reports `failed to fetch attestations: no matching attestations`, even though `cosign verify-attestation` succeeds locally against the same image. What's the most likely cause, and how do you fix it?

<details>
<summary>Show Answer</summary>

Modern Cosign (v3.x) defaults to pushing signatures and attestations in the newer Sigstore bundle format via the OCI 1.1 "referrers" API, rather than the older tag-based convention Kyverno's plain fetch path expects. Adding `type: SigstoreBundle` alongside `imageReferences` on the `verifyImages` entry tells Kyverno to look for and verify that newer bundle format — this is a real, version-dependent gotcha, not a policy-logic bug.
</details>

---

**7.** Kyverno's own documentation shows an attestation example using a field called `predicateType`. You apply that exact YAML against a live Kyverno v1.19.1 cluster. What happens?

<details>
<summary>Show Answer</summary>

The policy is still accepted, but Kyverno prints a deprecation warning: `predicateType has been deprecated use 'type: ...' instead`. The rule still functions with `predicateType`, but the field has been renamed to `type` in current Kyverno, and new policies should use `type` directly rather than the older documented field name.
</details>

---

**8.** This section's capstone lab combines `verifyImages` with a `validate` + `foreach` rule (checking per-container resource limits) instead of an `attestations` block, even though attestations were covered in the course text. Why?

<details>
<summary>Show Answer</summary>

Durability. A realistic attestation lab needs an image that's been signed *and* attested with your own key, which means either pushing to a registry this course doesn't have standing credentials for, or using an ephemeral, anonymous registry whose images expire long before the lab would next be graded. The `ghcr.io/kyverno/test-verify-image` repository used for signature checks is a permanent, project-maintained fixture — no equivalent permanent, pre-attested demo repository exists for custom predicate types. Combining `verifyImages` with a second, independent rule type is also a realistic shape for production policy: a supply-chain gate and a resource-hygiene gate are usually unrelated concerns enforced together in one policy.
</details>
