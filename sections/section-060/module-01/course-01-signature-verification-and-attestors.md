# Part 1: Signature Verification with verifyImages

## The problem no validate rule can solve

Go back to Section 010's very first example: a `validate.pattern` requiring a `team` label. That rule can reject a Pod for what it's missing, but it has no way to answer a completely different question: *is the image itself trustworthy?* A Pod can carry every label your organization demands and still be running an image nobody signed, nobody scanned, and nobody in your organization actually built.

Container image signing closes that gap. [Sigstore](https://sigstore.dev/) is the dominant open-source project for it, and [Cosign](https://github.com/sigstore/cosign) is its signing and verification CLI. The workflow, at a high level:

1. A CI pipeline builds an image and pushes it to a registry.
2. The pipeline signs the image with a private key (or, in "keyless" mode, via a short-lived certificate tied to an OIDC identity like a GitHub Actions workflow).
3. The signature itself is pushed to the *same registry*, as a separate OCI artifact linked to the image.
4. Anyone holding the matching public key can later verify that signature against the image — proving the image hasn't been swapped or tampered with since it was signed.

Kyverno's `verifyImages` rule automates step 4 at admission time: before a Pod is allowed to run a given image, Kyverno fetches the signature from the registry and checks it against a public key (or a keyless identity) you configure in the policy.

## The rule shape

`verifyImages` lives alongside `validate`, `mutate`, and `generate` as a rule type inside `spec.rules[]`. Here is a real, working policy — this is not a hypothetical, it verifies a public demo image the Kyverno project maintains specifically for this purpose:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: check-image-signature
spec:
  webhookConfiguration:
    failurePolicy: Fail
    timeoutSeconds: 30
  background: false
  rules:
    - name: check-image
      match:
        any:
          - resources:
              kinds:
                - Pod
      verifyImages:
        - imageReferences:
            - 'ghcr.io/kyverno/test-verify-image*'
          failureAction: Enforce
          attestors:
            - count: 1
              entries:
                - keys:
                    publicKeys: |-
                      -----BEGIN PUBLIC KEY-----
                      MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE8nXRh950IZbRj8Ra/N9sbqOPZrfM
                      5/KAQN0/KjHcorm/J5yctVd7iEcnessRQjU917hmKO6JWVGHpDguIyakZA==
                      -----END PUBLIC KEY-----
                    rekor:
                      ignoreTlog: true
                      url: https://rekor.sigstore.dev
```

Note the shape: `verifyImages` is a **list**, and each entry is its own self-contained check with its own `imageReferences` scope and its own `attestors`. A single rule can carry several `verifyImages` entries, each governing a different image family with a different key.

| Field | Job |
| --- | --- |
| `imageReferences` | Glob pattern(s) selecting which images this entry even looks at |
| `skipImageReferences` | Glob pattern(s) to exclude, even if they'd otherwise match `imageReferences` |
| `attestors` | The trust material (public keys, certificates, or keyless identities) the image's signature must satisfy |
| `attestors[].count` | How many of the listed `entries` must independently verify — `1` in a single-entry list just means "this one must pass" |
| `failureAction` | `Enforce` (block) or `Audit` (report only), scoped to this specific `verifyImages` entry |
| `mutateDigest` | Whether to rewrite the image reference to pin the resolved digest after a successful verification (default `true` — covered in Part 2) |

## imageReferences: scope this narrowly, on purpose

`imageReferences` does not accept variable interpolation — only static glob strings. That is a deliberate safety rail, and it exists because getting this field wrong has cluster-wide consequences.

> [!NOTE]
> If you set `imageReferences: ['*']` (or omit scoping and let a broad `match` reach every Pod without narrowing the image pattern), the rule will attempt to verify **every image the cluster ever pulls** — including Kyverno's own controller images, `kube-proxy`, CoreDNS, and anything else the control plane or your applications already run. None of those are signed with whatever key you just configured, and the moment this policy goes live in `Enforce` mode, the cluster stops being able to schedule almost anything. Always scope `imageReferences` to the specific repository (or repositories) your signing requirement actually applies to.

The example above scopes to `ghcr.io/kyverno/test-verify-image*` — a real, permanently-hosted repository the Kyverno project publishes with several tags, each demonstrating a different verification outcome: `signed` (valid signature, matching key), `unsigned` (no signature at all), and `signed-by-someone-else` (a valid signature, but from a different key than the one in the policy). This module's lab uses exactly this repository, which means you get to prove real signature verification end-to-end without running any signing infrastructure of your own.

## attestors: the trust material

`attestors[].entries[].keys.publicKeys` is the simplest form: a literal PEM-encoded public key, inline in the policy. (You can also reference a Kubernetes Secret via `k8s://<namespace>/<secret_name>`, which keeps the key out of the policy YAML itself — the Secret must expose the key under a field named `cosign.pub`.)

Two other attestor kinds exist for different trust models, though this course's lab uses `keys`:

- **`certificates`** — verify against an X.509 certificate chain, useful when your organization runs its own signing PKI rather than a bare keypair.
- **`keyless`** — verify against a Sigstore *keyless* identity: an OIDC issuer (e.g. `https://token.actions.githubusercontent.com`) plus a subject pattern (e.g. a specific GitHub Actions workflow path). No key material is stored anywhere; trust is rooted in Sigstore's public Fulcio certificate authority and the OIDC provider's own identity guarantees instead. This is the mechanism behind GitHub's built-in Artifact Attestations feature.

## The transparency log wrinkle

Every one of these attestor kinds can carry a nested `rekor` block. [Rekor](https://docs.sigstore.dev/logging/overview/) is Sigstore's public, append-only transparency log — every signature produced through the normal Sigstore flow gets a permanent, publicly-auditable entry there, and Kyverno's default behavior is to cross-check that entry actually exists as *part of* verifying the signature, not merely as an add-on.

That default is the right one for production, but it has a real, empirically-confirmed consequence for this module's lab: the `ghcr.io/kyverno/test-verify-image:signed` demo image was signed *without* a matching Rekor entry (a perfectly normal thing to do when signing offline, without `cosign`'s default transparency-log upload). Verify it against this key with the default Rekor-checking behavior, and Kyverno reports the signature as invalid — not because the signature is wrong, but because there's no transparency-log entry to corroborate it. Setting `rekor.ignoreTlog: true` tells Kyverno to skip that cross-check and trust the cryptographic signature verification alone. You will need this for the lab.

## failureAction: Enforce vs. the rule's own gate

`failureAction` on a `verifyImages` entry works exactly like `validationFailureAction` did back in Section 010 — `Enforce` blocks the request outright, `Audit` allows it through while recording the failure. The difference here is *where* it lives: it's a per-entry field inside `verifyImages`, not a single policy-wide switch, because a policy can carry multiple `verifyImages` entries (or mix `verifyImages` with `validate` rules) and you may want different failure behavior for each.

Apply that policy in the playground and run the two demo tags the Kyverno project
publishes for exactly this purpose. They differ only in whether a signature exists
in the registry alongside them — the image contents are irrelevant to the check.

> [!TIP]
> **Try it — the registry is consulted during admission**
>
> ```sh
> kubectl apply -f verify-policy.yaml
> kubectl run unsigned --image=ghcr.io/kyverno/test-verify-image:unsigned --restart=Never
> kubectl run signed --image=ghcr.io/kyverno/test-verify-image:signed --restart=Never
> ```
>
> Expect something like:
>
> ```text
> Error from server: admission webhook "mutate.kyverno.svc-fail" denied the request:
>
> resource Pod/default/unsigned was blocked due to the following policies
>
> check-image-signature:
>   check-image: 'failed to verify image ghcr.io/kyverno/test-verify-image:unsigned: .attestors[0].entries[0].keys: no matching signatures: invalid signature when validating ASN.1 encoded signature'
>
> pod/signed created
> ```
>
> This checkpoint needs outbound network access from the cluster to `ghcr.io` —
> Kyverno really does fetch the signature artifact mid-admission. An error
> mentioning a timeout or DNS rather than `no matching signatures` means the
> registry could not be reached, which is a different failure from a bad
> signature.

> [!NOTE]
> Look carefully at the webhook name in that error: `mutate.kyverno.svc-fail`, not a validating webhook. `verifyImages` is implemented inside Kyverno's *mutating* admission webhook, because a successful verification also needs to mutate the image reference (Part 2 covers exactly how). A failed verification simply denies the request from within that same mutating call instead of returning a patch. If you're debugging a `verifyImages` rejection by grepping webhook logs, look under the mutating webhook, not the validating one — this genuinely trips people up the first time they see it.

There is a third demo tag worth trying: `ghcr.io/kyverno/test-verify-image:signed-by-someone-else` is signed, but by a key that is not the one in your policy. Run it and compare the wording against `unsigned` — on this Kyverno version both collapse to the identical `no matching signatures: invalid signature when validating ASN.1 encoded signature` message. That is worth knowing before the exam: the error text alone does not tell you *which* of "not signed at all" or "signed by the wrong party" happened.
