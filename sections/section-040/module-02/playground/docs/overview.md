# Overview: Per-Element Mutation and Idempotency Playground

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass/fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it —
  the context is `kind-astro-ats-011-playground-0402`.
- **Kyverno v1.19.1**, installed with server-side apply, with all four
  controllers (admission, background, cleanup, reports) running in the
  `kyverno` namespace.
- **No policies.** Everything you see take effect is something you applied.

Expect the `kyverno.io/v1 ClusterPolicy is deprecated` warning on every apply of
a classic policy. It is expected on this version and safe to ignore.

## Things to try

- Apply the unguarded mirror rule, then label the same Pod three or four times
  and watch the prefix stack up.
- Add the per-element `preconditions` guard and repeat. Then move the same guard
  to rule level and find the Pod it now handles wrongly.
- Write a `foreach` over `initContainers` on a Pod that has none, and confirm it
  is a no-op rather than an error.
- Put two mutate rules on `spec.containers[*].image` in separate policies and see
  which value survives. Then restructure them so the question cannot arise.
- Add `operations: [CREATE]` and confirm an UPDATE no longer re-triggers the rule.

## When you're done

```sh
astrona destroy ats-011-playground-0402
```

(`astrona destroy` takes the environment name, not the config path.)
