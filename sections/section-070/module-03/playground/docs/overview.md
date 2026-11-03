# Overview: The Kyverno JMESPath Function Library Playground

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass/fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it —
  the context is `kind-astro-ats-011-playground-0703`.
- **Kyverno v1.19.1**, installed with server-side apply, with all four
  controllers (admission, background, cleanup, reports) running in the
  `kyverno` namespace.
- **No policies.** Everything you see take effect is something you applied.

Expect the `kyverno.io/v1 ClusterPolicy is deprecated` warning on every apply of
a classic policy. It is expected on this version and safe to ignore.

## Things to try

- Run `to_upper`, `split` and `truncate` on a label value inside a `deny` condition and read the message.
- Feed `regex_match` a name that almost matches and see which side of the pattern fails.
- Encode a string with `base64_encode`, decode it again, and compare the round trip.
- Compute a duration with `time_since` and compare it with `DurationGreaterThan`.
- Turn a labels map into key and value pairs with `items`.

## When you're done

```sh
astrona destroy ats-011-playground-0703
```

(`astrona destroy` takes the environment name, not the config path.)
