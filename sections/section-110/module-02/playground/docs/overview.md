# Overview: The CEL-Native Policy Family Playground

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass/fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it —
  the context is `kind-astro-ats-011-playground-1102`.
- **Kyverno v1.19.1**, installed with server-side apply, with all four
  controllers (admission, background, cleanup, reports) running in the
  `kyverno` namespace.
- **No policies.** Everything you see take effect is something you applied.

Expect the `kyverno.io/v1 ClusterPolicy is deprecated` warning on every apply of
a classic policy. It is expected on this version and safe to ignore.

## Things to try

- Apply a `MutatingPolicy` as `v1alpha1` and then as `v1`, and read the difference
  in what the API server says back.
- Write the same default-a-label rule twice — once as a `ClusterPolicy` mutate
  rule, once as a `MutatingPolicy` — and compare which you would rather maintain.
- Translate a Section 100 `ClusterCleanupPolicy` into a `DeletingPolicy` line by
  line, and find the field whose variable name changed.
- Delete a `MutatingPolicy` while a `ValidatingPolicy` depending on its default is
  still applied, and watch what starts failing.
- Check whether `status` ever populates on a `DeletingPolicy` after a sweep.

## When you're done

```sh
astrona destroy ats-011-playground-1102
```

(`astrona destroy` takes the environment name, not the config path.)
