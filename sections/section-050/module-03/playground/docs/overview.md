# Overview: Cloning Several Resources and generate foreach Playground

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass/fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it —
  the context is `kind-astro-ats-011-playground-0503`.
- **Kyverno v1.19.1**, installed with server-side apply, with all four
  controllers running in the `kyverno` namespace.
- **No policies.** Everything you see take effect is something you applied.
- A source namespace **`shared-config`** holding the ConfigMaps `app-settings`
  and `feature-flags` (both labelled `share=true`), the ConfigMap `private-notes`
  (no label), and the Secret `registry-auth` (labelled `share=true`).
- RBAC that lets the Kyverno background controller create, update and delete
  ConfigMaps and Secrets.

Expect the `kyverno.io/v1 ClusterPolicy is deprecated` warning on every apply of
a classic policy. It is expected on this version and safe to ignore.

## Things to try

- Write a `cloneList` rule with a `selector` and see which source objects arrive.
- Remove the `selector` and see that `private-notes` is cloned too.
- Edit a source ConfigMap with `synchronize: true` and watch the copies follow.
- Write a `foreach` rule over a list and look at `element` and `elementIndex`.
- Add a precondition that skips one element of the list.

## When you're done

```sh
astrona destroy ats-011-playground-0503
```

(`astrona destroy` takes the environment name, not the config path.)
