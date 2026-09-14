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

---

## Module 2 — Attestors, Digests, and Registry Access

**M2.1** An `attestors` list holds two blocks, each with one entry and one key. How many valid signatures must an image carry?

<details>
<summary>Show Answer</summary>

Two — one matching each block's key. Blocks are **ANDed**: every block must be satisfied. Verified on v1.19.1, an image correctly signed by the first block's key is still rejected, with the error naming `.attestors[1].entries[0].keys` so you can see exactly which block failed.
</details>

---

**M2.2** One block lists three trusted keys and does not set `count`. What does it require?

<details>
<summary>Show Answer</summary>

**All three.** Omitting `count` requires every entry in the block to match, which is the opposite of what a list of trusted signers usually intends. "Any of our three signers" must be written explicitly as `count: 1`.
</details>

---

**M2.3** Two entries, only one of which really signed the image. Give the verdict for `count: 1` and for `count: 2`.

<details>
<summary>Show Answer</summary>

`count: 1` → **admitted** (the threshold is met by the one genuine signature); `count: 2` → **denied**. Verified by changing only that value. `count` is an M-of-N threshold over the entries, so `count: 1` across two entries is an OR and `count: 2` across the same two is an AND expressed inside one block.
</details>

---

**M2.4** What does a `keyless` attestor match on, and why is it considered stronger than a long-lived key?

<details>
<summary>Show Answer</summary>

An **identity**: `subject` (who signed — for GitHub Actions, the workflow file and ref) plus `issuer` (the OIDC provider that asserted it). The signer authenticates to the provider, receives a short-lived Sigstore/Fulcio certificate binding that identity to a freshly-generated key, signs, publishes to the Rekor transparency log, and discards the private key within minutes. There is no long-lived secret to steal, so an attacker cannot satisfy the policy by exfiltrating a key — they would have to be able to act as the identity itself.
</details>

---

**M2.5** You set `mutateDigest: false` and submit a Pod referencing `…/app:signed` with no digest. What happens, and why?

<details>
<summary>Show Answer</summary>

It is **denied**, with `missing digest for …/app:signed`. Counter-intuitively, turning the mutation off makes the rule *stricter*. Verification is against specific image bytes identified by a digest; `mutateDigest: true` (the default) is what resolves the tag to a digest and records it. With it off, Kyverno will not resolve on the submitter's behalf, so a bare tag has nothing verifiable about it. An explicitly-digested reference passes the same policy and is stored exactly as submitted.
</details>

---

**M2.6** A colleague adds `skipImageReferences: ['ghcr.io/vendor/*']` to get one unsigned vendor image deployed. What is the risk?

<details>
<summary>Show Answer</summary>

A skipped reference is not verified **at all** — it is a bypass, not a downgrade — and a glob wider than intended silently removes verification from every image it covers. Unlike a failing rule, a skipped one produces no error to notice. Keep such globs as narrow as the exception actually is, ideally naming the exact image rather than a repository wildcard.
</details>

---

**M2.7** Your registry becomes unreachable. What happens to Pod admission, and what decides it?

<details>
<summary>Show Answer</summary>

The webhook's `failurePolicy` decides. With `Fail`, the API server rejects every request whose images match the rule — secure, and a cluster-wide outage for as long as the registry is down. With `Ignore`, the requests are admitted unverified — available, and a gap exactly when an attacker would want one. Neither is wrong; failing to choose is. Mitigate by scoping `imageReferences` tightly, keeping `timeoutSeconds` low, and leaving `useCache` on so every Pod creation is not a fresh round trip. Note also that Kyverno verifies **as itself**, not with the node's pull secrets — a private registry needs `imageRegistryCredentials`, and a credential problem surfaces as a verification failure rather than an auth error.
</details>

