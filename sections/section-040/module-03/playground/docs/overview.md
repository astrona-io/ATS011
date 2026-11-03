# Overview: Mutation Anchors Playground

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass/fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it —
  the context is `kind-astro-ats-011-playground-0403`.
- **Kyverno v1.19.1**, installed with server-side apply, with all four
  controllers (admission, background, cleanup, reports) running in the
  `kyverno` namespace.
- **No policies.** Everything you see take effect is something you applied.

Expect the `kyverno.io/v1 ClusterPolicy is deprecated` warning on every apply of
a classic policy. It is expected on this version and safe to ignore.

## Things to try

- Write a rule with `+(team): platform` and create one Pod with a `team` label
  and one without. Compare the two.
- Replace `+(team)` with a plain `team: platform` and repeat. See which Pod
  loses its own label.
- Add `+(automountServiceAccountToken): false` and create a Pod that sets the
  field to `true` itself.
- Add a `(name): "sidecar-*"` element to the containers list and create a Pod
  with `app`, `sidecar-log` and `sidecar-proxy` containers.
- Combine both: select containers with `(name)` and set a field with `+()`
  inside the same list element.

## When you're done

```sh
astrona destroy ats-011-playground-0403
```

(`astrona destroy` takes the environment name, not the config path.)
