# Solution

## Step 1: Save the policy

An attestor set with `count: 1` accepts the image when any one entry verifies. Save this as `clusterpolicy-verify-release-images.yaml`:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-release-images
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: verify-release
      match:
        any:
          - resources:
              kinds: ["Pod"]
              namespaces: ["verify-lab"]
      verifyImages:
        - imageReferences:
            - "registry.example.com/release/*"
          required: true
          verifyDigest: true
          mutateDigest: false
          attestors:
            - count: 1
              entries:
                - keys:
                    publicKeys: |-
                      -----BEGIN PUBLIC KEY-----
                      MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAELFiirYPYcwEFMbEv7nYJuE/5WQc0
                      Ox0C8jKEagGYozS47gNJlxlJy1HwqncV87vQKDnjQpS12rkuKrIFsGiiPg==
                      -----END PUBLIC KEY-----
                - keys:
                    publicKeys: |-
                      -----BEGIN PUBLIC KEY-----
                      MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEUlBtC7gimHMLQFrdNFdSPfr+n/1b
                      3dYisddhReOn7ZYG91AVnBOpmiaP4RY4j5qBWFc7/KMaSWJYJHOlsQeLGg==
                      -----END PUBLIC KEY-----
```

Apply it with `kubectl apply -f clusterpolicy-verify-release-images.yaml`, then run `astrona submit -c sections/section-060/module-02/labs/lab-01`.
