# Overview: Pattern-Based Validation Playground

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass/fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it —
  the context is `kind-astro-ats-011-playground-010`.
- **Kyverno v1.19.1**, installed with server-side apply, with all four
  controllers (admission, background, cleanup, reports) running in the
  `kyverno` namespace.
- **No policies.** The cluster has zero `ClusterPolicy` objects on it. Every
  policy you see take effect is one you wrote.

Expect the `kyverno.io/v1 ClusterPolicy is deprecated` warning on every apply.
It is expected on this version and safe to ignore.

## Things to try

- Apply a `validate.pattern` rule in `Audit` mode, create a violating Pod, and
  find the violation in `kubectl get policyreport -A` rather than in an error.
  Then switch the same policy to `Enforce` and watch the same Pod get rejected.
- Write a pattern with `?*` and one with `*` on the same field, and find a value
  that one accepts and the other does not.
- Point a rule at a field that does not exist on the resource you submit, and
  see whether it is treated as a failure or as nothing at all.
- Add a second rule to the same `ClusterPolicy` and check which rule name shows
  up in the rejection message when both would fail.
- Write a deliberately unhelpful `message`, trigger it, then rewrite it to say
  what the developer should actually change — the difference is the whole point
  of the field.

## When you're done

```sh
astrona destroy ats-011-playground-010
```

(`astrona destroy` takes the environment name, not the config path.)
