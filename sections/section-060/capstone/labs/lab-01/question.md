# Question

Solve this question against the `kind` cluster provisioned for this lab (Kyverno is already installed and running in the `kyverno` namespace). This capstone combines `verifyImages` with a validation technique from earlier in the course.

As in the module lab, `ghcr.io/kyverno/test-verify-image` is a permanently-hosted Kyverno demo repository with these tags:

* `signed` — signed with the private key that pairs with the public key below.
* `unsigned` — carries no signature at all.

Write and apply one or more `ClusterPolicy` resources, all in `Enforce` mode, that together govern every Pod cluster-wide:

1. **Image signature (`verifyImages`):** Any image matching `ghcr.io/kyverno/test-verify-image*` must carry a valid Cosign signature verifiable against:

   ```
   -----BEGIN PUBLIC KEY-----
   MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE8nXRh950IZbRj8Ra/N9sbqOPZrfM
   5/KAQN0/KjHcorm/J5yctVd7iEcnessRQjU917hmKO6JWVGHpDguIyakZA==
   -----END PUBLIC KEY-----
   ```

   (Same transparency-log note as the module lab applies — this signature predates a Rekor upload.)

2. **Per-container resource limits (`validate` + `foreach`):** Independent of which image is used, every container in a Pod — there may be more than one — must declare both `resources.limits.cpu` and `resources.limits.memory`. A Pod can fail this rule and pass the signature rule, or the reverse; each is a separate gate the Pod must clear.

3. Do not restrict either rule to a single namespace or a single container position; both must apply cluster-wide and to every container in a Pod.

You may split this across as many rules or policies as you like, and name everything however you like.

> Why not require a signed *attestation* (SBOM, provenance, code-review) here instead of a second rule? Because a realistic attestation lab needs an image you sign and attest yourself, and any registry you can freely push to as part of a self-contained lab either requires credentials this course doesn't have, or is ephemeral and would expire long before this lab is graded again. The module lab's course text still covers attestation syntax and shows it working; this capstone instead proves you can combine `verifyImages` with a rule type from earlier in the course, against durable, permanently-hosted images — which is the more common real-world shape of a Kyverno image policy anyway.
