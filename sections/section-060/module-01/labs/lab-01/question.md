# Question

Solve this question against the `kind` cluster provisioned for this lab (Kyverno is already installed and running in the `kyverno` namespace).

The Kyverno project publishes a small, permanently-hosted demo image repository, `ghcr.io/kyverno/test-verify-image`, specifically for testing image signature verification. Several tags exist in that repository:

* `signed` — signed with the private key that pairs with the public key below.
* `unsigned` — carries no signature at all.
* `signed-by-someone-else` — signed, but with a *different* key than the one below.

Write and apply a `ClusterPolicy` that governs every Pod cluster-wide:

1. The rule must apply only to images matching `ghcr.io/kyverno/test-verify-image*` — do not verify every image in the cluster (that would also block Kyverno's own and Kubernetes' own system images, which are not signed with this key).
2. A matching image must carry a valid Cosign signature verifiable against the following public key:

   ```
   -----BEGIN PUBLIC KEY-----
   MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE8nXRh950IZbRj8Ra/N9sbqOPZrfM
   5/KAQN0/KjHcorm/J5yctVd7iEcnessRQjU917hmKO6JWVGHpDguIyakZA==
   -----END PUBLIC KEY-----
   ```

3. A matching image that fails verification (no signature, or a signature from a different key) must be **rejected outright** — use `Enforce`, not `Audit`.
4. Do not restrict the policy to a single namespace; it must apply cluster-wide.

You may name the policy and its rule however you like.

> Tip: this particular signature was produced without publishing to the public Rekor transparency log, so your attestor's `keys` entry will need to tell Kyverno not to require a transparency-log lookup for it.
