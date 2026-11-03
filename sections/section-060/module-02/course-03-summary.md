# Summary

An `attestors` list holds entries, and each entry has an `entries` list of keys, certificates or keyless identities. The `count` field turns the list into an M-of-N requirement. Without `count`, every entry must be satisfied. A key-based entry matches a public key, a certificate entry matches a certificate chain, and a keyless entry matches the subject and issuer of the identity that signed.

`mutateDigest` resolves a tag to a digest and rewrites the stored resource. `verifyDigest` only requires that the image already has a digest. Turning `mutateDigest` off therefore makes a rule stricter for the user. `skipImageReferences` scopes a rule, and an image it skips is not verified at all. `required: false` lets an unsigned image through when no signature exists.

Kyverno verifies images itself, so a private registry needs `imageRegistryCredentials`. Because verification is a live external call inside admission, the webhook `failurePolicy` decides whether a registry outage blocks all requests or lets them through.

Key facts:

- `count` makes an M-of-N attestor requirement.
- `mutateDigest` changes the resource; `verifyDigest` does not.
- A skipped image reference is not verified.

<!-- astrona:playground:destroy -->
