# Overview: JSON Patches Playground

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass/fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it —
  the context is `kind-astro-ats-011-playground-080`.
- **Kyverno v1.19.1**, installed with server-side apply, with all four
  controllers (admission, background, cleanup, reports) running in the
  `kyverno` namespace.
- **No policies.** The cluster has zero policy objects on it. Everything you
  see take effect is something you applied.

Expect the `kyverno.io/v1 ClusterPolicy is deprecated` warning on every apply of
a classic policy. It is expected on this version and safe to ignore.

## Things to try

- Append to a container's `env` array with `op: add` and `/-` on a Pod that has
  `env` and on one that does not, and compare.
- Target an annotation key containing a `/` without escaping it as `~1`, and work
  out from the error what the pointer actually addressed.
- Run the same missing path through `add`, `remove`, and `replace` in three
  separate rules — the three behave differently, and one of them will reject every
  Pod in the cluster until you delete it.
- Order two operations so the second one's array index depends on what the first
  one did.

## When you're done

```sh
astrona destroy ats-011-playground-080
```

(`astrona destroy` takes the environment name, not the config path.)
