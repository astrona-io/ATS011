# Overview: Validation Anchors Playground

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass/fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it —
  the context is `kind-astro-ats-011-playground-0103`.
- **Kyverno v1.19.1**, installed with server-side apply, with all four
  controllers (admission, background, cleanup, reports) running in the
  `kyverno` namespace.
- **No policies.** Everything you see take effect is something you applied.

Expect the `kyverno.io/v1 ClusterPolicy is deprecated` warning on every apply of
a classic policy. It is expected on this version and safe to ignore.

## Things to try

- Write the same requirement twice — once with a conditional anchor, once with a
  `deny` condition — and decide which one you would rather re-read in a year.
- Take a rule with `=()` on an optional block, remove the anchor, and find the
  resource that now gets rejected for the wrong reason.
- Put a compliant element last in a long list and confirm `^()` still matches.
- Give `X()` a value other than `"null"` and check whether it changes anything.
- Replace a `<()` with `()` in the pull-secret example and see which Pods start
  getting rejected that should not be.

## When you're done

```sh
astrona destroy ats-011-playground-0103
```

(`astrona destroy` takes the environment name, not the config path.)
