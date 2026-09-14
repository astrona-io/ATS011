# Overview: Cleanup Policies Playground

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass/fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it —
  the context is `kind-astro-ats-011-playground-100`.
- **Kyverno v1.19.1**, installed with server-side apply, with all four
  controllers (admission, background, cleanup, reports) running in the
  `kyverno` namespace.
- **No policies.** The cluster has zero policy objects on it. Everything you
  see take effect is something you applied.
- **No cleanup permissions.** The `kyverno-cleanup-controller` ServiceAccount
  cannot delete anything yet — granting it is a large part of what this module
  is about.

Expect the `kyverno.io/v1 ClusterPolicy is deprecated` warning on every apply of
a classic policy. It is expected on this version and safe to ignore.

## Things to try

- Apply a `ClusterCleanupPolicy` before granting any RBAC and read the exact
  refusal. It is worth seeing before you fix it.
- Grant `pods` to the cleanup controller with an aggregating `ClusterRole`, then
  confirm with `kubectl auth can-i delete pods --as=system:serviceaccount:kyverno:kyverno-cleanup-controller`.
- Time a sweep: create a matching Pod just after a minute boundary and check
  `status.lastExecutionTime` against when it actually disappeared.
- Label a Pod `cleanup.kyverno.io/ttl=30s` *before* granting RBAC, and find the
  only place the failure is recorded.
- Move a filter from `match` into `conditions` and back, and note which one can
  express an annotation test.

## When you're done

```sh
astrona destroy ats-011-playground-100
```

(`astrona destroy` takes the environment name, not the config path.)
