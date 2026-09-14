# Overview: The podSecurity Subrule Playground

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass/fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it —
  the context is `kind-astro-ats-011-playground-0104`.
- **Kyverno v1.19.1**, installed with server-side apply, with all four
  controllers (admission, background, cleanup, reports) running in the
  `kyverno` namespace.
- **No policies.** Everything you see take effect is something you applied.

Expect the `kyverno.io/v1 ClusterPolicy is deprecated` warning on every apply of
a classic policy. It is expected on this version and safe to ignore.

## Things to try

- Apply `level: restricted` in `Audit` and read how many of the cluster's own
  existing Pods violate it.
- Take the restricted-compliant Pod from Part 1, remove one `securityContext`
  field at a time, and match each removal to the control that starts complaining.
- Add an `exclude` for a control, then remove it, and diff the two failure
  messages to see the block appear and disappear.
- Label a namespace `pod-security.kubernetes.io/enforce=restricted` and confirm
  that Pods are rejected there even with no Kyverno policy at all.
- Pin `version` to an old release such as `v1.24` and compare against `latest`.

## When you're done

```sh
astrona destroy ats-011-playground-0104
```

(`astrona destroy` takes the environment name, not the config path.)
