# Part 2: Attestations & Digest Pinning

## Beyond "is it signed": attestations

A signature answers exactly one question: *did the holder of this key sign this exact set of bytes?* It says nothing about *what those bytes are* — which Git commit built them, which CI pipeline ran, whether a Software Bill of Materials (SBOM) was generated, whether a vulnerability scan passed, or whether a human reviewed the code before merge. Those richer claims are called **attestations**: signed statements, in the [in-toto attestation format](https://github.com/in-toto/attestation), that get pushed to the registry alongside the image the same way a signature does.

An attestation's payload has a `predicateType` (what kind of claim this is — a URI, often self-defined by whoever produces it) and a `predicate` (the actual claim data, arbitrary JSON):

```json
{
  "payloadType": "https://example.com/CodeReview/v1",
  "payload": {
    "_type": "https://in-toto.io/Statement/v0.1",
    "predicateType": "https://example.com/CodeReview/v1",
    "subject": [
      { "name": "registry.io/org/app", "digest": { "sha256": "b31bfb4d..." } }
    ],
    "predicate": {
      "author": "alice@example.com",
      "repo": { "branch": "main", "type": "git", "uri": "https://git-repo.com/org/app" },
      "reviewers": ["bob@example.com"]
    }
  },
  "signatures": [{ "keyid": "", "sig": "MEYCIQ..." }]
}
```

Nothing about that scheme is fixed to code review — SBOMs, SLSA build provenance, and vulnerability-scan reports all ride the exact same mechanism, just with a different `predicateType` and a different-shaped `predicate`.

## The attestations block

Kyverno's `verifyImages.attestations` verifies that a specific predicate type is present, signed by a trusted attestor, and — optionally — that specific fields inside the decoded predicate satisfy conditions you write:

```yaml
verifyImages:
  - imageReferences:
      - 'registry.io/org/app*'
    failureAction: Enforce
    attestations:
      - type: https://example.com/CodeReview/v1
        attestors:
          - entries:
              - keys:
                  publicKeys: |-
                    -----BEGIN PUBLIC KEY-----
                    MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEzDB0FiCzAWf/BhHLpikFs6p853/G
                    3A/jt+GFbOJjpnr7vJyb28x4XnR1M5pwUUcpzIZkIgSsd+XcTnrBPVoiyw==
                    -----END PUBLIC KEY-----
        conditions:
          - all:
              - key: '{{ repo.uri }}'
                operator: Equals
                value: 'https://git-repo.com/org/app'
              - key: '{{ repo.branch }}'
                operator: Equals
                value: 'main'
```

> [!NOTE]
> Kyverno's own documentation examples for this block use a field named `predicateType`. Against a live Kyverno v1.19.1 cluster, applying a policy with `predicateType` succeeds but prints a deprecation warning: `predicateType has been deprecated use 'type: ...' instead`. Use `type` — it's the field shown above, and it's what the rest of this page uses throughout.

`conditions` uses the same `{{ }}` variable syntax as `validate.message` (Section 070 covers this in full) — here, each key resolves against the *decoded predicate*, not the whole Pod, so `{{ repo.branch }}` reaches into `predicate.repo.branch` from the JSON shown above.

`attestors{}` appears in two different places in a `verifyImages` entry, and they mean different things:

- Directly under `verifyImages` (Part 1's example) — verifies the **image signature itself**.
- Under `attestations[].attestors` (this page's example) — verifies **who signed the attestation**, which may be a completely different signer than whoever signed the image.

Kyverno's own documentation is explicit on this point: **"Each verifyImages rule can be used to verify signatures or attestations, but not both."** One entry does one job. If you need both a signature check and an attestation check on the same image family, write two separate entries (or two separate rules) — exactly the structure this module's capstone lab uses, just with a `validate` rule standing in for the second gate.

## Signing an attestation (for context, not required by the lab)

```bash
cosign generate-key-pair
cosign attest --key cosign.key --predicate predicate.json --type https://example.com/CodeReview/v1 my-registry.example.com/app:v1
```

`predicate.json` holds just the `predicate` object — Cosign wraps it in the in-toto envelope, signs it, and pushes it as a separate OCI artifact linked to the image, the same way `cosign sign` pushes a plain signature.

> [!NOTE]
> **Discovered behavior worth knowing, not just for the exam:** modern Cosign (v3.x, the version this course's tooling uses) defaults to pushing signatures and attestations in the newer [Sigstore bundle format](https://github.com/sigstore/protobuf-specs/blob/main/protos/sigstore_bundle.proto) via the OCI 1.1 "referrers" API, rather than the older tag-based convention (`<image>:sha256-<digest>.att`). Verified empirically against a live cluster: a `verifyImages.attestations` entry using the plain `keys` attestor form shown above returned `failed to fetch attestations: no matching attestations` against an image that Cosign v3 had, in fact, correctly attested — because Kyverno was looking for the older tag-based artifact and it simply didn't exist in that form. Adding `type: SigstoreBundle` at the `verifyImages` entry level (a sibling of `imageReferences`, matching the shape Kyverno's own docs use for verifying GitHub Artifact Attestations) fixed it immediately, and the same attestation then verified successfully. If you ever see "no matching attestations" against an image you're confident was attested, check which Cosign version produced it and whether `type: SigstoreBundle` is needed.

Because a durable, self-signed, permanently-hosted attestation demo image isn't something this course can host indefinitely (registries you can freely push to for a lab either require credentials this course doesn't have, or are ephemeral and would expire long before the lab is graded again), this module's **capstone lab does not exercise attestation verification directly** — it combines `verifyImages` signature checking with a `validate` rule instead, both against the durable `ghcr.io/kyverno/test-verify-image` repository. The syntax and behavior above are real and empirically verified; you just won't be graded on reproducing them against your own registry in this course.

## mutateDigest: pinning what you just verified

Recall from Part 1 that `verifyImages` runs inside Kyverno's *mutating* webhook. Here's why: on a successful verification, Kyverno's default behavior (`mutateDigest: true`) rewrites the Pod's image reference to include the exact digest that was just verified.

Empirically, on a live cluster, admitting `ghcr.io/kyverno/test-verify-image:signed` produces a persisted Pod spec of:

```
ghcr.io/kyverno/test-verify-image:signed@sha256:b31bfb4d0213f254d361e0079deaaebefa4f82ba7aa76ef82e90b4935ad5b105
```

Notice what did *not* happen: Kyverno did not strip the `:signed` tag and replace it with just the digest. It **appended** the digest onto the existing tag reference, producing a combined `tag@digest` form. Both `kubectl` and the container runtime treat this as fully valid — when both a tag and a digest are present, the digest is authoritative — and the practical effect is the same either way: this specific Pod is now pinned to the exact image bytes that were verified, immune to a later re-push of a different image under the same tag. `verifyDigest` (a related, separate field) goes further and can *require* that incoming image references already specify a digest, rejecting bare-tag references outright rather than mutating them.

This is the real payoff of combining signature verification with digest pinning: it isn't just "was this signed at admission time," it's "the thing running right now is provably the thing that was signed," for the lifetime of that Pod.

The claim is easy to check, and worth checking rather than believing, because the
difference between "Kyverno verified this" and "Kyverno verified this *and*
pinned it" is invisible in the admission response — both just say the Pod was
created.

> [!TIP]
> **Try it — read back what the cluster stored**
>
> ```sh
> kubectl run signed --image=ghcr.io/kyverno/test-verify-image:signed --restart=Never
> kubectl get pod signed -o jsonpath='{.spec.containers[0].image}'
> ```
>
> Expect something like:
>
> ```text
> pod/signed created
> ghcr.io/kyverno/test-verify-image:signed@sha256:b31bfb4d0213f254d361e0079deaaebefa4f82ba7aa76ef82e90b4935ad5b105
> ```
>
> You submitted a bare `:signed` tag. What the cluster stored is that tag *plus*
> the digest Kyverno resolved and verified. If someone re-pushes a different
> image under the `:signed` tag tomorrow, this Pod is unaffected — it is pinned
> to bytes, not to a name.

The digest you see will match the one above only for as long as the Kyverno
project keeps that demo tag pointing at the same image; treat the specific
`sha256:` value as an example, and the `@sha256:` *suffix* as the thing that
matters. That suffix is exactly what a grading script — or a real audit — looks
for as evidence that verification and pinning both ran.
