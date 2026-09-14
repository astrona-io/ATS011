# Overview: Background Scanning Playground

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass/fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it —
  the context is `kind-astro-ats-011-playground-030`.
- **Kyverno v1.19.1**, installed with server-side apply, with all four
  controllers (admission, background, cleanup, reports) running in the
  `kyverno` namespace.
- **No policies.** The cluster has zero policy objects on it. Everything you
  see take effect is something you applied.
- **Two Pods already exist in the `legacy` namespace** (`legacy-web`, with no
  labels; `legacy-cache`, labelled `team=platform`). They were created before
  you apply anything — which is exactly the situation background scanning is
  for.

Expect the `kyverno.io/v1 ClusterPolicy is deprecated` warning on every apply of
a classic policy. It is expected on this version and safe to ignore.

## Things to try

- Apply an `Audit` policy that the `legacy` Pods violate and watch
  `kubectl get policyreport -n legacy` populate without you touching the Pods.
- Flip `spec.background` between `true` and `false` on the same policy and see
  which reports survive.
- Write a rule whose precondition reads `{{ request.operation }}`, then check
  whether it produces any result at all for a resource that was never admitted
  while the policy existed.
- Delete a `PolicyReport` by hand and see how long it takes to come back.

## When you're done

```sh
astrona destroy ats-011-playground-030
```

(`astrona destroy` takes the environment name, not the config path.)
