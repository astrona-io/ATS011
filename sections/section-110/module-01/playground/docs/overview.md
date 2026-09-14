# Overview: CEL in Kyverno Policies Playground

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass/fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it —
  the context is `kind-astro-ats-011-playground-110`.
- **Kyverno v1.19.1**, installed with server-side apply, with all four
  controllers (admission, background, cleanup, reports) running in the
  `kyverno` namespace.
- **No policies.** The cluster has zero policy objects on it. Everything you
  see take effect is something you applied.

Expect the `kyverno.io/v1 ClusterPolicy is deprecated` warning on every apply of
a classic policy. It is expected on this version and safe to ignore.

## Things to try

- Write the same rule twice — once as `validate.pattern`, once as `validate.cel`
  — and compare the rejection messages.
- Write a CEL expression that indexes an optional field without `has()`, apply
  it, and read the warning Kyverno prints at apply time before you ever submit a
  resource.
- With that same unguarded rule applied, try to *delete* a Pod. Have
  `kubectl delete clusterpolicy` ready.
- Apply a `ValidatingPolicy` from `policies.kyverno.io` and compare its webhook
  name in an error against a `ClusterPolicy`'s.
- Turn on `autogen.validatingAdmissionPolicy.enabled` and watch a real
  `ValidatingAdmissionPolicy` and binding appear — then see how the rejection
  message changes.

## When you're done

```sh
astrona destroy ats-011-playground-110
```

(`astrona destroy` takes the environment name, not the config path.)
