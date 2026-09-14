# Overview: Autogen Rules Playground

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass/fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it —
  the context is `kind-astro-ats-011-playground-090`.
- **Kyverno v1.19.1**, installed with server-side apply, with all four
  controllers (admission, background, cleanup, reports) running in the
  `kyverno` namespace.
- **No policies.** The cluster has zero policy objects on it. Everything you
  see take effect is something you applied.

Expect the `kyverno.io/v1 ClusterPolicy is deprecated` warning on every apply of
a classic policy. It is expected on this version and safe to ignore.

## Things to try

- Apply a rule matching only `kind: Pod`, then `kubectl create deployment` and
  read which rule name appears in the rejection.
- Inspect `status.autogen.rules` and compare the rewritten paths for the
  Deployment group against the CronJob one.
- Add `pod-policies.kyverno.io/autogen-controllers: none` and watch
  `status.autogen` empty out.
- Add `Namespace` alongside `Pod` in the same `match` entry and see what autogen
  does then.
- Scope autogen to `Deployment` only, submit a non-compliant `Job`, and follow
  what happens to the Pod the Job controller tries to create.

## When you're done

```sh
astrona destroy ats-011-playground-090
```

(`astrona destroy` takes the environment name, not the config path.)
