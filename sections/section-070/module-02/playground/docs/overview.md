# Overview: Context Beyond apiCall Playground

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass/fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it —
  the context is `kind-astro-ats-011-playground-0702`.
- **Kyverno v1.19.1**, installed with server-side apply, with all four
  controllers (admission, background, cleanup, reports) running in the
  `kyverno` namespace.
- **No policies.** Everything you see take effect is something you applied.
- A **`policy-config` namespace** with an `allowed-registries` ConfigMap already
  seeded, so the `configMap` context examples work immediately.

Expect the `kyverno.io/v1 ClusterPolicy is deprecated` warning on every apply of
a classic policy. It is expected on this version and safe to ignore.

## Things to try

- Edit the `allowed-registries` ConfigMap and confirm the next rejection message
  quotes the new value with no policy change.
- Delete that ConfigMap entirely and see what the rule does — and what it does
  not tell you.
- Use a `variable` entry with `keys(...)` to dump the top-level keys of any
  context object you are unsure about. It works on `request` too.
- Reference a nested `imageRegistry` field directly in a `message`, then via a
  `variable` entry, and compare what renders.
- Point an `imageRegistry` entry at a private image the cluster cannot pull and
  read the failure.

## When you're done

```sh
astrona destroy ats-011-playground-0702
```

(`astrona destroy` takes the environment name, not the config path.)
