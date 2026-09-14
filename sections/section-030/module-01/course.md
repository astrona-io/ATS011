# Background Scanning

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS011/tree/main/sections/section-030/module-01/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS011.git -c sections/section-030/module-01/playground
> astrona destroy ats-011-playground-030
> ```

Every rule you wrote in Section 010 only ever fired at one moment: the instant something was admitted to the cluster. `kubectl apply` a Pod, the API server hands the object to Kyverno's webhook, Kyverno checks it against your patterns, and the decision is made -- accepted or rejected -- before the object is ever persisted. That is admission control, and it has a hard limit built into its name: it only controls *admission*. It has nothing to say about the thousands of Pods, Deployments, and ConfigMaps that were already sitting in etcd before your policy existed.

This module covers the mechanism that closes that gap: `spec.background`, the field that turns a Kyverno policy from "a gate at the door" into "a gate at the door, plus a periodic walk through everything already inside the building."

## How this module is organised

1. **[Part 1 — What Background Scanning Actually Does](./course-01-what-background-scans-do.md)** -- the difference between admission-time enforcement and periodic re-evaluation, and how results surface as `PolicyReport` / `ClusterPolicyReport` objects.
2. **[Part 2 — Request Context and the Limits of a Scan](./course-02-request-context-and-limits.md)** -- why a rule that depends on `request.operation` or `request.userInfo` behaves differently once there's no live admission request behind it, and when to reach for `spec.background: false`.

## Learning objectives

After this module you can:

- Explain the difference between admission-time validation and a background scan, and why the second exists at all.
- Read a `PolicyReport` (namespaced) or `ClusterPolicyReport` (cluster-scoped) and interpret its `results[]` entries -- `pass`, `fail`, and `skip`.
- Explain why `spec.background: true` (the default) is what makes a policy visible to resources that predate it, and what happens when it's `false`.
- Identify which parts of Kyverno's variable vocabulary (`request.object`, `request.namespace`, `request.operation`) survive into a background scan, and which (`request.userInfo` and similar) do not.
- Predict, for a rule gated by `request.operation`, what result a background scan will actually produce, and explain why.

## Before you start

You should already be comfortable with everything from Section 010: `match`/`exclude`, `validate.pattern`, wildcard operators, and the difference between `Enforce` and `Audit`. This module assumes you can already write a working validation rule -- the new material here is entirely about *when* that rule gets evaluated, not how to write its pattern.

The linked lab gives you a `kind` cluster with Kyverno already installed, plus a namespace populated with Pods created *before* any policy exists. You will write the policy, then prove it reaches backward in time to report on those Pods -- without ever touching, blocking, or deleting them.

The **playground** linked at the top of this page gives you the same environment with nothing to submit: a single-node `kind` cluster with Kyverno v1.19.1 running and **no policies installed**, plus two Pods already running in the `legacy` namespace that predate anything you apply. Once it is up, `kubectl` is already pointed at it — the context is `kind-astro-ats-011-playground-030` (Astrona prefixes the environment name with `astro-`). The `Try it` checkpoints in the parts below assume that environment is already running; they never repeat the startup command.
