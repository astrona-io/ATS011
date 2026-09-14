# Overview: Policy Objects and Rule Anatomy Playground

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass/fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it —
  the context is `kind-astro-ats-011-playground-000`.
- **Kyverno v1.19.1**, installed with server-side apply, with all four
  controllers (admission, background, cleanup, reports) running in the
  `kyverno` namespace.
- Two empty namespaces, **`team-prod`** and **`team-staging`**, so you can watch
  one policy behave differently in each.
- **No policies.** Everything you see take effect is something you applied.

## Things to try

- Write the same rule twice — once as a `ClusterPolicy`, once as a namespaced
  `Policy` in `team-staging` — and find a resource each one does and does not
  govern.
- Apply one `Audit` policy with `validationFailureActionOverrides` set to
  `Enforce` for `team-prod` only, then submit the identical violating Pod to
  both namespaces.
- Put a `mutate` rule and a `validate` rule that contradict each other in two
  separate policies, and work out from the admitted object which ran first.
- Write a `PolicyException` for one Deployment and confirm the rule still
  governs everything else in the same namespace.
- Delete a policy while a violating resource already exists, and check whether
  anything happens to the resource.

## When you're done

```sh
astrona destroy ats-011-playground-000
```

(`astrona destroy` takes the environment name, not the config path.)
