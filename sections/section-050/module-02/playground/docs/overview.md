# Overview: Generating for What Already Exists Playground

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass/fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it —
  the context is `kind-astro-ats-011-playground-0502`.
- **Kyverno v1.19.1**, installed with server-side apply, with all four
  controllers (admission, background, cleanup, reports) running in the
  `kyverno` namespace.
- **No policies.** Everything you see take effect is something you applied.
- Two namespaces, **`legacy-a`** and **`legacy-b`**, created at startup before any
  policy exists — the natural subjects for a retroactive generate rule.

Expect the `kyverno.io/v1 ClusterPolicy is deprecated` warning on every apply of
a classic policy. It is expected on this version and safe to ignore.

## Things to try

- Apply a generate rule without `generateExisting`, confirm `legacy-a` stays
  empty, then add the field and watch it fill in.
- Delete the policy and time how long the downstream survives. Then repeat with
  `orphanDownstreamOnPolicyDelete: true`.
- Check a generated resource's `metadata.ownerReferences` and confirm it is empty,
  then look at its `generate.kyverno.io/*` labels instead.
- Narrow the rule's `match` with a label selector so one namespace stops matching,
  and see what happens to that namespace's generated resource.
- Combine `generateExisting: true` with `synchronize: false` and work out which of
  the two behaviours you just gave up.

## When you're done

```sh
astrona destroy ats-011-playground-0502
```

(`astrona destroy` takes the environment name, not the config path.)
