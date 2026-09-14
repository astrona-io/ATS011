# Overview: Generation Rules Playground

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass/fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it —
  the context is `kind-astro-ats-011-playground-050`.
- **Kyverno v1.19.1**, installed with server-side apply, with all four
  controllers (admission, background, cleanup, reports) running in the
  `kyverno` namespace.
- **No policies.** The cluster has zero policy objects on it. Everything you
  see take effect is something you applied.

Expect the `kyverno.io/v1 ClusterPolicy is deprecated` warning on every apply of
a classic policy. It is expected on this version and safe to ignore.

## Things to try

- Apply a `generate` rule keyed on Namespace creation, then `kubectl create ns`
  something and watch the downstream resource appear.
- Edit a generated resource by hand with `synchronize: true`, then again with
  `synchronize: false`, and compare what survives.
- Delete a generated resource outright and see whether it comes back.
- Change the source resource a `clone` points at and watch the copies follow.
- Look at the `UpdateRequest` objects (`kubectl get updaterequests -A`) Kyverno
  creates to drive generation.

## When you're done

```sh
astrona destroy ats-011-playground-050
```

(`astrona destroy` takes the environment name, not the config path.)
