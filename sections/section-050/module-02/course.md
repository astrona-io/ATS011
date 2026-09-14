# Generating for What Already Exists

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS011/tree/main/sections/section-050/module-02/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS011.git -c sections/section-050/module-02/playground
> astrona destroy ats-011-playground-0502
> ```

Module 1's generate rules all share a shape: something is created, and the rule fires. A new Namespace appears, and a `NetworkPolicy` appears with it.

That leaves the same gap Section 030 found for validation. The rule protects everything created from now on, and does nothing whatsoever about the namespaces that were already there when you applied it — which, on any cluster that has been running for a while, is most of them.

`generateExisting` closes it, and in doing so raises two questions Module 1 never had to answer. What happens to a generated resource when the policy that created it is **deleted**? And what happens when the trigger stops matching — a namespace relabelled out of the rule's scope?

The answers are not what most people guess, and one of them can take a cluster's network policy with it.

## How this module is organised

1. **[Part 1 — generateExisting and Retroactive Creation](./course-01-generate-existing.md)** — turning a forward-looking rule into one that also backfills, how long that takes, and what it means for a rule that was safe to apply when it only governed new resources.
2. **[Part 2 — Lifecycle: Policy Deletion and Orphaning](./course-02-lifecycle-and-orphaning.md)** — what happens to downstream resources when the policy is deleted, the `orphanDownstreamOnPolicyDelete` field, and how the generate lifecycle differs from ordinary Kubernetes garbage collection.

## Learning objectives

After this module you can:

- Use `generateExisting` to apply a generate rule retroactively to resources that already exist.
- Explain why a rule that is safe as a forward-looking policy may not be safe as a retroactive one.
- Predict what happens to generated resources when their policy is deleted, under the default and with `orphanDownstreamOnPolicyDelete: true`.
- Explain why generated resources are not cleaned up by Kubernetes' own garbage collector.
- Decide, for a given resource type, whether the downstream should follow the policy's lifetime or outlive it.

## Before you start

You need Module 1 of this section: `generate.data`, `generate.clone`, and `synchronize` semantics. Section 030's distinction between admission-time and background evaluation is the right mental model for what `generateExisting` does — it is the generate-side equivalent of a background scan.

The checkpoints create and delete cluster-scoped policy objects and namespaced network policies. Nothing here is destructive to a playground, but Part 2's mechanism is precisely the one to be careful with on a real cluster.

The **playground** linked at the top of this page gives you a `kind` cluster with Kyverno v1.19.1 running and **no policies installed**, plus two namespaces (`legacy-a`, `legacy-b`) that predate anything you apply. Once it is up, `kubectl` is already pointed at it — the context is `kind-astro-ats-011-playground-0502` (Astrona prefixes the environment name with `astro-`). The `Try it` checkpoints in the parts below assume that environment is already running; they never repeat the startup command.
