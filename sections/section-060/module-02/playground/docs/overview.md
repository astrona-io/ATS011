# Overview: Attestors, Digests, and Registry Access Playground

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass/fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it —
  the context is `kind-astro-ats-011-playground-0602`.
- **Kyverno v1.19.1**, installed with server-side apply, with all four
  controllers (admission, background, cleanup, reports) running in the
  `kyverno` namespace.
- **No policies.** Everything you see take effect is something you applied.

Expect the `kyverno.io/v1 ClusterPolicy is deprecated` warning on every apply of
a classic policy. It is expected on this version and safe to ignore.

## Things to try

- Put the same two keys in one block with `count: 1`, then `count: 2`, and confirm
  only the count changed the verdict.
- Drop `count` entirely from a two-entry block and work out from the result what
  the default is.
- Split a two-key requirement into two blocks, break one, and compare how the
  error reads against the single-block form.
- Set `mutateDigest: false` and submit a bare tag, then the same image pinned to a
  digest.
- Write a `skipImageReferences` glob wider than you intended and check how much
  verification quietly disappears.

## When you're done

```sh
astrona destroy ats-011-playground-0602
```

(`astrona destroy` takes the environment name, not the config path.)
