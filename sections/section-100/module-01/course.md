# Cleanup Policies

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS011/tree/main/sections/section-100/module-01/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS011.git -c sections/section-100/module-01/playground
> astrona destroy ats-011-playground-100
> ```

Every rule type in this course so far has been reactive to an *arrival*. Something was submitted to the API server, and your policy got a say: admit it, rewrite it, create something alongside it, check its signature. A cleanup policy inverts that entirely. Nothing is arriving. The resource has been sitting in the cluster, perfectly valid, possibly for days — and your policy's job is to decide it should not be there any more.

Because of that inversion, a `CleanupPolicy` looks almost nothing like the `ClusterPolicy` you are used to. There is no `rules` array, no `validate` or `mutate` block, no `validationFailureAction`. There is a `match` block (which will look familiar), an optional `conditions` block, and a **cron `schedule`**. A separate controller — the `kyverno-cleanup-controller` Deployment you can see running in the `kyverno` namespace — wakes on that schedule, lists what matches, and deletes it.

That architecture introduces one requirement the admission-time policy types never had: the controller needs genuine Kubernetes **permission to delete** the kind you are targeting, and by default it has almost none. Kyverno does not let you find this out the hard way — it rejects the policy at apply time. Getting that right is most of what makes this policy type feel different.

## How this module is organised

1. **[Part 1 — Schedules, Matching, and the RBAC Requirement](./course-01-schedules-matching-and-rbac.md)** — the `CleanupPolicy` and `ClusterCleanupPolicy` shape, cron schedules and what they guarantee about timing, selecting victims with `match`, and the aggregating `ClusterRole` that makes deletion possible at all.
2. **[Part 2 — Conditions, TTL Labels, and Deletion Semantics](./course-02-conditions-ttl-and-deletion-semantics.md)** — narrowing with `conditions` over the `target` variable, the per-resource `cleanup.kyverno.io/ttl` label as a lighter alternative, `deletionPropagationPolicy`, and how the newer CEL-based `DeletingPolicy` relates to all of this.

## Learning objectives

After this module you can:

- Explain how a cleanup policy differs architecturally from every admission-time rule type, and name the controller that executes it.
- Write a `ClusterCleanupPolicy` and a namespaced `CleanupPolicy` with a correct cron `schedule` and a `match` block that selects by kind, namespace, and label selector.
- Diagnose the `cleanup controller has no permission to delete kind <Kind>` admission error and fix it with a `ClusterRole` carrying the `rbac.kyverno.io/aggregate-to-cleanup-controller` label.
- Narrow a cleanup policy with a `conditions` block written against the `target` variable.
- Choose between a cleanup policy and the `cleanup.kyverno.io/ttl` label for a given requirement, and state what timing guarantee either one actually gives you.

## Before you start

You should be comfortable with `match`/`exclude` resource selection (Section 010) and with writing `all`/`any` condition entries using `{{ }}` variables and operators (Sections 020 and 070). Part 2's `conditions` block reuses that exact syntax against a different variable.

You do not need anything from Sections 040–090. You will also touch Kubernetes RBAC — `ClusterRole` and label-based role aggregation — which the module explains as it goes rather than assuming.

The linked lab gives you a `kind` cluster with Kyverno already installed and running. Cleanup is a scheduled operation, so expect to wait up to a minute for a deletion to actually happen; that wait is part of the mental model, not a slow lab.

The **playground** linked at the top of this page gives you the same environment with nothing to submit: a single-node `kind` cluster with Kyverno v1.19.1 running and **no policies installed**. Once it is up, `kubectl` is already pointed at it — the context is `kind-astro-ats-011-playground-100` (Astrona prefixes the environment name with `astro-`). The `Try it` checkpoints in the parts below assume that environment is already running; they never repeat the startup command.
