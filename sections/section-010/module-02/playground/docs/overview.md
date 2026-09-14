# Overview: Deny Rules and the Condition Vocabulary Playground

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass/fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it —
  the context is `kind-astro-ats-011-playground-0102`.
- **Kyverno v1.19.1**, installed with server-side apply, with all four
  controllers (admission, background, cleanup, reports) running in the
  `kyverno` namespace.
- **No policies.** Everything you see take effect is something you applied.

Expect the `kyverno.io/v1 ClusterPolicy is deprecated` warning on every apply of
a classic policy. It is expected on this version and safe to ignore.

## Things to try

- Write the same requirement twice — once as a `pattern`, once as a `deny` —
  and confirm they reject the same resources. Then flip one condition's polarity
  and watch it reject the complement.
- Swap `conditions.any` for `conditions.all` on a two-condition rule and find a
  resource that one rejects and the other admits.
- Give a condition an operator with the wrong case (`anyIn`) and read what
  happens at apply time rather than at admission time.
- Compare `512Mi` against `1Gi` with `LessThan`, then with `Equals`, and see which
  one understands quantities.
- Drop the `|| ''` fallback from a condition on an optional label and submit a
  resource that lacks it.

## When you're done

```sh
astrona destroy ats-011-playground-0102
```

(`astrona destroy` takes the environment name, not the config path.)
