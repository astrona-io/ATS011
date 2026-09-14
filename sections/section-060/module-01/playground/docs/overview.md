# Overview: Image Signature & Attestation Verification Playground

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass/fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it —
  the context is `kind-astro-ats-011-playground-060`.
- **Kyverno v1.19.1**, installed with server-side apply, with all four
  controllers (admission, background, cleanup, reports) running in the
  `kyverno` namespace.
- **No policies.** The cluster has zero policy objects on it. Everything you
  see take effect is something you applied.
- **No `cosign` CLI.** Bootstrap scripts here run against the cluster, not on a
  shell inside it, so installing a client binary would land it on whatever
  machine ran `astrona run` rather than anywhere useful. You do not need it for
  the checkpoints in this module: Kyverno itself fetches and verifies signatures
  from the registry during admission. If you want to inspect signatures by hand,
  install `cosign` on your own machine from
  [sigstore/cosign](https://github.com/sigstore/cosign).
- **Outbound network access to `ghcr.io`** is required, because verification is
  a live registry lookup made mid-admission rather than anything cached locally.

Expect the `kyverno.io/v1 ClusterPolicy is deprecated` warning on every apply of
a classic policy. It is expected on this version and safe to ignore.

## Things to try

- Point a `verifyImages` rule at a public image that is genuinely signed and one
  that is not, and compare the admission results.
- Turn on `mutateDigest` and check what the persisted Pod spec says the image is,
  compared to what you submitted.
- Set `required: false` and see how the rule's behaviour changes for an unsigned
  image.
- Watch what `kubectl get pod <name> -o jsonpath='{.spec.containers[0].image}'`
  reports after a successful verification, and compare it with what you
  submitted.

## When you're done

```sh
astrona destroy ats-011-playground-060
```

(`astrona destroy` takes the environment name, not the config path.)
