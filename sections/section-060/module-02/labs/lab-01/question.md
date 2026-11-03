# Question

Kyverno is installed and the namespace `verify-lab` exists. Write a `ClusterPolicy` named `verify-release-images` with `validationFailureAction: Enforce` and `background: false` that contains one `verifyImages` rule for Pods in `verify-lab`:

1. Verify images that match `registry.example.com/release/*`.
2. Use one attestor set with `count: 1` and two key entries, so that a signature from either key is accepted. Use these two public keys:

```text
Key A:
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAELFiirYPYcwEFMbEv7nYJuE/5WQc0
Ox0C8jKEagGYozS47gNJlxlJy1HwqncV87vQKDnjQpS12rkuKrIFsGiiPg==
-----END PUBLIC KEY-----
Key B:
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEUlBtC7gimHMLQFrdNFdSPfr+n/1b
3dYisddhReOn7ZYG91AVnBOpmiaP4RY4j5qBWFc7/KMaSWJYJHOlsQeLGg==
-----END PUBLIC KEY-----
```

3. Set `required: true`, `verifyDigest: true` and `mutateDigest: false`.

Images outside `registry.example.com/release/*` must not be touched by the rule. An image that matches cannot be verified in this lab (the registry is not reachable), so the Pod is rejected.
