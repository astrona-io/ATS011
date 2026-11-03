# Summary

A `verifyImages` rule checks the supply chain of an image. A `validate` rule can only read the image name, but a `verifyImages` rule checks that the image was signed by a key or identity you trust. `imageReferences` selects the images to check and `skipImageReferences` excludes some. An `attestors` block holds the public key or other trust anchor, and signatures are normally checked against the Rekor transparency log too.

An `attestations` block verifies a signed statement about the image, selected by its type, and `conditions` can test fields of the decoded statement. Image verification failures are reported by the admission webhook that ran the rule, so the message shows which webhook to look at. By default the rule also has `mutateDigest` enabled, which replaces the tag in the stored Pod with the digest that was verified. That prevents the tag from later pointing to different content.

Key facts:

- `verifyImages` checks signatures and attestations; `validate` cannot.
- `mutateDigest` pins the verified digest in the stored resource.
- Narrow the rule with `imageReferences`.

<!-- astrona:playground:destroy -->
