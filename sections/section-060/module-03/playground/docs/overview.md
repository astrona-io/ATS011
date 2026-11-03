# Overview: The images Variable and Image Extraction Playground

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass/fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it —
  the context is `kind-astro-ats-011-playground-0603`.
- **Kyverno v1.19.1**, installed with server-side apply, with all four
  controllers (admission, background, cleanup, reports) running in the
  `kyverno` namespace.
- **No policies.** Everything you see take effect is something you applied.

Expect the `kyverno.io/v1 ClusterPolicy is deprecated` warning on every apply of
a classic policy. It is expected on this version and safe to ignore.

## Things to try

- Write a validate rule whose message is `{{ images.containers.*.registry }}` and
  read what a Pod with two containers prints.
- Add an init container and print `images.initContainers.*.name`.
- Create an image reference with no tag, then one with a digest, and compare the
  `tag` and `digest` values.
- Apply the same rule to a Pod and to a Deployment and compare the outcome.
- Add an `imageExtractors` entry for a custom resource kind and check what the
  rule sees.

## When you're done

```sh
astrona destroy ats-011-playground-0603
```

(`astrona destroy` takes the environment name, not the config path.)
