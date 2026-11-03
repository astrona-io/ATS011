# Part 2: Validating Signed Manifests

## The problem: who changed this manifest?

Image signatures protect a container image. They do not protect the Kubernetes manifest that runs it. Anyone who can write to the cluster can submit a Deployment with a different image, extra privileges or a changed command, and the image signature stays valid.

The `validate.manifests` subrule closes that gap. It checks that the manifest itself was signed by a trusted party, and that the signature still matches the content of the resource. If the signature is missing, from the wrong key, or does not match the content, Kyverno rejects the request.

This part is conceptual. The playground has no signing key and no signed manifest, so there is nothing to apply and verify here. The examples show structure only.

## The structure of the rule

```yaml
validate:
  failureAction: Enforce
  message: "The manifest must be signed by the platform team."
  manifests:
    attestors:
      - count: 1
        entries:
          - keys:
              publicKeys: |-
                -----BEGIN PUBLIC KEY-----
                (the PEM-encoded public key goes here)
                -----END PUBLIC KEY-----
```

An *attestor* is a party whose signature you trust. `attestors` is a list. Each item has `entries`, the individual signers, and a `count`, the number of those entries that must have signed. With `count: 1` and one entry, one valid signature from that key is enough. With three entries and `count: 2`, any two of the three must have signed.

An entry names a key in one of the supported ways. The example uses a static public key in PEM format, which is the simplest. Entries can also describe keyless signing, where a certificate identity is used instead of a stored key.

The signature itself travels with the resource, so it must be added to the manifest before you apply it. The signing happens outside the cluster, in your delivery pipeline.

## Fields that change after signing

A signed manifest is a fixed document. Kubernetes and its controllers change fields after you apply it: the API server adds defaults, a controller adds a status, and a horizontal autoscaler changes `spec.replicas`. If Kyverno compared every field, these legitimate changes would fail the signature check.

`ignoreFields` lists the fields that may differ from the signed original:

```yaml
manifests:
  attestors:
    - entries:
        - keys:
            publicKeys: |-
              (PEM-encoded public key)
  ignoreFields:
    - objects:
        - kind: Deployment
      fields:
        - spec.replicas
```

Each item names the `objects` it applies to, by `kind`, and the `fields` that are allowed to change. Keep the list as short as possible. Every field you add is a field that an attacker can change without breaking the signature.

## Dry run

To decide whether the live resource matches the signed one, Kyverno can compare against what the API server would store. The `dryRun` field turns this on and names a namespace in which Kyverno performs the dry run:

```yaml
manifests:
  dryRun:
    enable: true
    namespace: kyverno-dryrun
```

Use a dedicated namespace. Kyverno's service account needs permission to create the resource kinds you verify there. Cluster-scoped resources and custom resources may need extra permissions, so check what the rule needs before you enforce it.

## Where `manifests` fits

`validate.manifests` is one of the validate subrules, next to `pattern`, `deny`, `podSecurity` and `assert`. A rule uses exactly one of them. Use it for provenance: "this exact manifest came from our pipeline". Use the other subrules for content: "this manifest follows our rules".

The next page is the lab for this module. It grades only the assertion tree, because grading a signed manifest needs signing infrastructure that the lab does not have.

## Common pitfalls

> [!WARNING]
> **Common pitfalls**
>
> - **Signing the image but not the manifest.** The two checks protect different things.
> - **Forgetting `ignoreFields`.** Fields such as `spec.replicas` change after signing, and a strict check rejects the resource.
> - **Making `ignoreFields` too wide.** A field on the list can be changed without breaking the signature.
> - **Using one shared key with `count: 1` for every team.** Anyone with that key can sign anything. Use separate entries and a higher `count` for sensitive resources.
> - **Starting in `Enforce`.** Begin with `Audit`, read the reports, and enforce once legitimate changes are covered.

## Your mission: Assertion Trees Lab

You can now write a `validate.assert` rule with expressions, `~.` iteration and bindings, and you know how a signed-manifest rule is built. The mission asks you to write one assertion tree that rejects Pods with the default service account, a `:latest` image or a missing memory limit.

Pause the playground, start the lab, and submit your work as often as you like:

```sh
astrona stop ats-011-playground-0105
astrona run --git ssh://git@github.com/astrona-io/ATS011.git -c sections/section-010/module-05/labs/lab-01
astrona submit -c sections/section-010/module-05/labs/lab-01
```

When the lab passes, remove it and return to the playground:

```sh
astrona destroy ats-011-lab-015
astrona start ats-011-playground-0105
```
