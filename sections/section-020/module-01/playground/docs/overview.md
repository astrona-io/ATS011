# Overview: Preconditions Playground

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass/fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it —
  the context is `kind-astro-ats-011-playground-020`.
- **Kyverno v1.19.1**, installed with server-side apply, with all four
  controllers (admission, background, cleanup, reports) running in the
  `kyverno` namespace.
- **No policies.** The cluster has zero policy objects on it. Everything you
  see take effect is something you applied.

Expect the `kyverno.io/v1 ClusterPolicy is deprecated` warning on every apply of
a classic policy. It is expected on this version and safe to ignore.

## Things to try

- Write one rule whose `preconditions` gate on `{{ request.operation }}`, then
  create a resource and update it — watch the same rule fire on one and skip the
  other.
- Move a namespace restriction from `preconditions` into `match` and back, and
  compare what `kubectl get events` and the reports show in each case.
- Give a precondition a key that does not resolve on the submitted resource, with
  and without a `|| ''` fallback, and see which one errors.
- Put two entries under `all`, then the same two under `any`, and find a resource
  that one accepts and the other rejects.

## When you're done

```sh
astrona destroy ats-011-playground-020
```

(`astrona destroy` takes the environment name, not the config path.)
