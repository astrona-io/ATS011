# Solution Guide: VerifyImage Rules

This guide builds a `ClusterPolicy` with a single `verifyImages` rule, scoped to one demo image repository, that checks a real Cosign signature against a real public key.

---

## Step 1: Write the policy

Create `policy.yaml`:

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

A few choices worth explaining:

- **`imageReferences: ['ghcr.io/kyverno/test-verify-image*']`** — this is the single most important field to get right. Leave it out or set it to `'*'` and the rule verifies *every* image the cluster ever pulls, including Kyverno's own controller images and every core Kubernetes system image — none of which are signed with this key. That would brick the cluster the moment the policy went live.
- **`count: 1`** under `attestors` — how many of the listed entries must independently verify. With one entry, `count: 1` just means "this one must pass," but the field matters more once you list several attestors (e.g. requiring 2-of-3 signers).
- **`rekor.ignoreTlog: true`** — this demo image's signature was produced and pushed without also uploading a matching entry to the public Rekor transparency log. Without `ignoreTlog: true`, Kyverno would try to cross-check the signature against Rekor, find nothing, and fail verification even though the signature itself is completely valid. This is a real, empirically-confirmed requirement for this exact demo image — omitting it produces a `signature not found in transparency log` style failure even against the `signed` tag.
- **`failureAction: Enforce`** here is set on the `verifyImages` entry itself (the modern per-rule location), not `spec.validationFailureAction`. Both forms exist in Kyverno; the per-entry field is the current recommended one for `verifyImages`.

---

## Step 2: Apply it

```bash
kubectl apply -f policy.yaml
kubectl get clusterpolicy check-image-signature
```

You should see `READY: True` (plus the usual `kyverno.io/v1 ClusterPolicy is deprecated` warning — expected, ignore it).

---

## Step 3: Prove it against all three tags

```bash
# Unsigned — rejected
kubectl run unsigned --image=ghcr.io/kyverno/test-verify-image:unsigned --restart=Never
# Error from server: admission webhook "mutate.kyverno.svc-fail" denied the request:
# ...
# check-image-signature:
#   check-image: 'failed to verify image ghcr.io/kyverno/test-verify-image:unsigned:
#     .attestors[0].entries[0].keys: no matching signatures: invalid signature when
#     validating ASN.1 encoded signature'

# Signed with a DIFFERENT key — rejected, same style of error
kubectl run signed-other --image=ghcr.io/kyverno/test-verify-image:signed-by-someone-else --restart=Never
# Error from server: admission webhook "mutate.kyverno.svc-fail" denied the request: ...

# Correctly signed — admitted
kubectl run signed --image=ghcr.io/kyverno/test-verify-image:signed --restart=Never
# pod/signed created

kubectl get pod signed -o jsonpath='{.spec.containers[0].image}'
# ghcr.io/kyverno/test-verify-image:signed@sha256:b31bfb4d0213f254d361e0079deaaebefa4f82ba7aa76ef82e90b4935ad5b105
```

> [!NOTE]
> Notice the error is reported by the webhook named **`mutate.kyverno.svc-fail`**, not the validating one — even though the outcome is a hard rejection. `verifyImages` is implemented in Kyverno's *mutating* webhook, because on success it also has to rewrite the image reference to add the resolved digest. A verification failure short-circuits that same mutating call with a denial instead of a patch. This is a genuinely useful fact to remember when reading `kubectl describe` output or webhook logs on the exam and in practice: a `verifyImages` denial and a `mutate` denial look identical in the webhook name, and only the message text tells them apart.

> [!NOTE]
> Look closely at the persisted image on the admitted Pod: `ghcr.io/kyverno/test-verify-image:signed@sha256:b31bfb...`. Kyverno's default `mutateDigest: true` behavior does **not** strip the tag and replace it with a digest — it *appends* the resolved digest onto the existing tag, producing a combined `tag@digest` reference. Both parts of that reference are honored by the container runtime (the digest wins), and the result is fully immutable: even if someone re-pushes a different image under the `:signed` tag later, this specific Pod's spec is now pinned to the exact bytes that were verified at admission time.

Clean up your scratch Pods when you're done (`kubectl delete pod unsigned signed-other signed --ignore-not-found`); the grading script creates and cleans up its own test Pods independently in a dedicated namespace.
