# Part 2: Digests, Scope, and Registry Access

## Two digest fields, and the surprising one

Module 1 met `mutateDigest` as the field that rewrites an admitted image reference to pin the verified digest. There is a second, similarly-named field — `verifyDigest` — and the relationship between them is not what the names suggest.

Both default to `true`. Testing each in turn against the same bare-tag reference produced this:

| Setting | Bare tag `…:signed` | Persisted reference |
| :--- | :--- | :--- |
| `verifyDigest: true` *(default)* | **admitted** | rewritten to `…:signed@sha256:b31bfb…` |
| `mutateDigest: false` | **denied** — `missing digest for ghcr.io/kyverno/test-verify-image:signed` | — |

Turning the *mutation* off made the policy **stricter**, not laxer. That is worth sitting with, because it is the opposite of the intuition the field name creates.

The mechanism explains it. Verification is against a specific set of image bytes, identified by digest. When a submitter provides only a tag, something has to resolve that tag to a digest — and `mutateDigest: true` is what does the resolving and then records the result in the spec. Switch it off and Kyverno will not resolve on the submitter's behalf, so a reference that carries no digest has nothing verifiable about it, and the rule fails with `missing digest`.

So `mutateDigest: false` effectively means *"the submitter must already have pinned a digest."* An explicitly-digested reference sails through the same policy untouched:

> [!TIP]
> **Try it — off means "you pin it", not "never mind"**
>
> ```sh
> kubectl apply -f mutate-digest-false.yaml
> kubectl run md2 --image=ghcr.io/kyverno/test-verify-image:signed --restart=Never
>
> kubectl apply -f - <<'EOF'
> apiVersion: v1
> kind: Pod
> metadata: {name: md-digest}
> spec:
>   containers:
>     - name: app
>       image: "ghcr.io/kyverno/test-verify-image:signed@sha256:b31bfb4d0213f254d361e0079deaaebefa4f82ba7aa76ef82e90b4935ad5b105"
> EOF
> kubectl get pod md-digest -o jsonpath='{.spec.containers[0].image}'
> ```
>
> Expect something like:
>
> ```text
> dig-probe:
>   probe: missing digest for ghcr.io/kyverno/test-verify-image:signed
>
> pod/md-digest created
> ghcr.io/kyverno/test-verify-image:signed@sha256:b31bfb4d0213f254d361e0079deaaebefa4f82ba7aa76ef82e90b4935ad5b105
> ```
>
> Same policy, two submissions. The bare tag is rejected outright; the
> pre-pinned reference is admitted and stored **exactly as submitted** — no
> rewriting, because there was nothing left to resolve.

Which you want depends on who you trust to pin. Leaving `mutateDigest` at its default is the convenient posture: developers write tags, Kyverno resolves and records digests, and the persisted spec is pinned either way. Setting it `false` pushes that responsibility onto whoever writes the manifest, which is stricter but means a rejected deploy rather than a silently-corrected one.

## Narrowing with `skipImageReferences`

`imageReferences` selects which images an entry verifies. `skipImageReferences` carves exceptions out of that selection — the same relationship `exclude` has to `match` at rule level.

```yaml
verifyImages:
  - imageReferences:
      - 'ghcr.io/kyverno/test-verify-image*'
    skipImageReferences:
      - 'ghcr.io/kyverno/test-verify-image:unsigned'
    failureAction: Enforce
    attestors: [ ... ]
```

Verified behaviour: with that skip in place, the `:unsigned` image — which the rule would otherwise reject — is **admitted**, while `:signed` continues to verify normally. The skip is a genuine bypass, not a downgrade: nothing is checked for a skipped reference.

That makes it the right tool for a documented, narrow exception — a vendor image you cannot get signed, an upstream base image outside your signing pipeline — and a dangerous one for anything broader. A glob that is wider than intended silently removes verification from every image it covers, and unlike a failing rule, a skipped one leaves no error to notice.

> [!NOTE]
> The rule also has a `required` field, and its behaviour did not reproduce in testing. Neither of the two obvious readings — "make verification advisory" and "every image must be covered by some verifyImages rule" — produced any observable difference on Kyverno v1.19.1: with `required: false` an unsigned matching image was still denied, and with `required: true` an image matching no `imageReferences` pattern was still admitted. Rather than guess at semantics that did not show up, treat `skipImageReferences` as the field that demonstrably scopes a rule, and do not rely on `required` to relax one.

## Private registries

Everything so far used a public registry. A private one needs credentials, and Kyverno does **not** inherit the node's image-pull credentials — the kubelet's pull happens later and elsewhere. Verification is Kyverno reaching out to the registry itself, mid-admission, as itself.

`imageRegistryCredentials` is where those credentials go, referencing image-pull secrets and/or enabling cloud provider helpers:

```yaml
verifyImages:
  - imageReferences:
      - 'registry.internal.example.com/*'
    imageRegistryCredentials:
      allowInsecureRegistry: false
      providers:
        - default
      secrets:
        - registry-credentials
    attestors: [ ... ]
```

The playground has no private registry, so this one is schema-accurate rather than demonstrated. The failure mode is worth recognising even so: a credential problem surfaces as a verification failure, not as an authentication error, because from the rule's point of view the signature simply could not be fetched.

## When the registry cannot be reached

This is the operational consequence of everything above, and the reason `verifyImages` deserves more caution than a `validate` rule.

A `validate.pattern` evaluates against data already in the request — it cannot fail for external reasons. A `verifyImages` rule makes a **network call to a host outside your cluster while a request is waiting**. Registries have outages, DNS fails, egress rules change.

What happens then depends on the webhook's failure policy, which Module 1's policy set explicitly:

```yaml
spec:
  webhookConfiguration:
    failurePolicy: Fail
    timeoutSeconds: 30
```

* **`failurePolicy: Fail`** — the webhook could not produce an answer, so the API server rejects the request. Your cluster stops admitting Pods whose images match the rule, for as long as the registry is unreachable. Secure, and an outage.
* **`failurePolicy: Ignore`** — the request is admitted without verification. Available, and a hole exactly when an attacker would most like one.

Neither is wrong; the choice is a stated risk posture. What *is* wrong is not choosing — and the practical mitigations are the same either way: scope `imageReferences` tightly so fewer workloads depend on the call, keep `timeoutSeconds` low enough that a hung registry does not stall admission, and understand that `useCache` (default `true`) is what stops every single Pod creation becoming a fresh round trip.

> [!WARNING]
> **Common pitfalls**
>
> - **Reading `mutateDigest: false` as a relaxation.** It removes Kyverno's digest resolution, which makes bare-tag references fail.
> - **Expecting Kyverno to use the node's pull secrets.** It does not; supply `imageRegistryCredentials`.
> - **Writing a broad `skipImageReferences` glob.** A skipped image is not verified at all, and nothing reports it.
> - **Leaving `failurePolicy` unconsidered on a registry-dependent rule.** One setting turns a registry outage into a cluster outage; the other turns it into an unverified deploy.
> - **Relying on `required` to make verification optional.** It did not behave that way in testing.

## Section recap

`mutateDigest` is what resolves a tag to the digest verification needs, so turning it off makes a rule stricter by demanding the submitter pin one. `skipImageReferences` is the field that demonstrably scopes a rule, and a skipped image is not verified at all. Private registries need `imageRegistryCredentials` because Kyverno verifies as itself rather than as the kubelet. And because verification is a live external call inside the admission path, the webhook's `failurePolicy` decides whether a registry outage becomes a cluster outage or a silent gap — a decision to make deliberately rather than inherit.
