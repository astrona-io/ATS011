# Overview: Variables & API Calls in Policies Playground

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass/fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it —
  the context is `kind-astro-ats-011-playground-070`.
- **Kyverno v1.19.1**, installed with server-side apply, with all four
  controllers (admission, background, cleanup, reports) running in the
  `kyverno` namespace.
- **No policies.** The cluster has zero policy objects on it. Everything you
  see take effect is something you applied.
- **Three Pods already run in the `team-a` namespace**, labelled `team=a`, so a
  `context.apiCall` has something real to count.

Expect the `kyverno.io/v1 ClusterPolicy is deprecated` warning on every apply of
a classic policy. It is expected on this version and safe to ignore.

## Things to try

- Write a rule with a `context.apiCall` that counts Pods in the requesting
  namespace, echo the count into the failure `message`, and trigger it.
- Break the JMESPath in a variable on purpose and read how Kyverno reports an
  unresolved variable versus a failed rule.
- Compare `{{ request.object.<field> }}` against `{{ request.oldObject.<field> }}`
  on an update.
- Query a resource the Kyverno service account cannot read and see what the
  failure looks like — that is a realistic production failure mode.

## When you're done

```sh
astrona destroy ats-011-playground-070
```

(`astrona destroy` takes the environment name, not the config path.)
