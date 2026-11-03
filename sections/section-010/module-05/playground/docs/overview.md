# Overview: Assertion Trees and Manifest Verification Playground

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass/fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it —
  the context is `kind-astro-ats-011-playground-0105`.
- **Kyverno v1.19.1**, installed with server-side apply, with all four
  controllers (admission, background, cleanup, reports) running in the
  `kyverno` namespace.
- **No policies.** Everything you see take effect is something you applied.
- **No signing infrastructure.** There is no signing key and no signed
  manifest, so `validate.manifests` cannot be exercised here.

Expect the `kyverno.io/v1 ClusterPolicy is deprecated` warning on every apply of
a classic policy. It is expected on this version and safe to ignore.

## Things to try

- Write a `validate.assert` rule that rejects the `default` service account and
  read the failure message.
- Replace `~.containers` with a plain `containers` key and compare what a
  one-container Pod and a two-container Pod do.
- Bind a value with `->name` and use `$name` in a child check.
- Write the same requirement once with `pattern` and once with `assert`, and
  compare the failure messages.

## When you're done

```sh
astrona destroy ats-011-playground-0105
```

(`astrona destroy` takes the environment name, not the config path.)
