# Overview: Mutation Rules Playground

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass/fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it —
  the context is `kind-astro-ats-011-playground-040`.
- **Kyverno v1.19.1**, installed with server-side apply, with all four
  controllers (admission, background, cleanup, reports) running in the
  `kyverno` namespace.
- **No policies.** The cluster has zero policy objects on it. Everything you
  see take effect is something you applied.
- **Two Pods already exist in the `legacy` namespace** (`legacy-web`,
  `legacy-cache`), created before any policy — the natural targets for a
  `mutateExisting` rule.

Expect the `kyverno.io/v1 ClusterPolicy is deprecated` warning on every apply of
a classic policy. It is expected on this version and safe to ignore.

## Things to try

- Apply a `patchStrategicMerge` rule and create a Pod, then `kubectl get pod -o yaml`
  and find the field you added.
- Write a list patch with and without the `(name)` anchor and compare what
  happens to a two-container Pod. One of the two corrupts the resource — find out
  which, and read the API server's complaint.
- Try a `mutateExisting` rule against the `legacy` Pods. Nothing happens, because
  Kyverno's background controller holds no update permission on Pods here — grant
  it with a `ClusterRole` labelled
  `rbac.kyverno.io/aggregate-to-background-controller: "true"` and try again. The
  silence before the grant is worth seeing once.
- Apply a mutate rule and a validate rule that disagree, and work out from the
  admitted object which one ran first.

## When you're done

```sh
astrona destroy ats-011-playground-040
```

(`astrona destroy` takes the environment name, not the config path.)
