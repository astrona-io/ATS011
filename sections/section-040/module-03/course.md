# Mutation Anchors

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS011/tree/main/sections/section-040/module-03/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS011.git -c sections/section-040/module-03/playground
> astrona destroy ats-011-playground-0403
> ```

Module 2 showed that a mutate rule runs again on every matching operation, and that a change which does not check the current state can overwrite or compound. For per-element computed values the answer was a `preconditions` guard inside `foreach`.

For a large class of mutations there is a lighter tool. Many policies only want to supply a default: set a label if the owner did not, turn a flag off unless the workload chose otherwise. Kyverno gives `patchStrategicMerge` anchors for this, written into the patch itself. The add-if-not-present anchor `+()` writes a field only when it is missing. The conditional anchor `()` restricts a patch to the list elements that match a value, including a wildcard.

This module covers both, separately and then together.

## How this module is organised

1. **[Part 1 — The add-if-not-present anchor](./course-01-add-if-not-present-anchor.md)** — `+(field)`, how it differs from a plain overwrite, and why it is idempotent by construction.
2. **[Part 2 — Conditional Anchors in Mutation](./course-02-conditional-anchors-in-mutation.md)** — `(name): "sidecar-*"` as a filter on list elements, and combining it with `+()`.

The module closes with a summary page and a mission, **Mutation Anchors Lab**, a graded lab that asks you to write and apply the policies from this module on a live cluster.

## Learning objectives

After this module you can:

- Write a `patchStrategicMerge` that sets a field only when it is missing, using `+(field)`.
- Explain the difference between `+(team): platform` and `team: platform`.
- Explain why an add-if-not-present patch is safe to run again on UPDATE.
- Select list elements with a conditional anchor such as `(name): "sidecar-*"`.
- Combine a conditional anchor with `+()` to default a field on matching elements only.

## Before you start

You need Modules 1 and 2 of this section: `patchStrategicMerge`, the `(name)` anchor used with `"*"`, and the idea that a mutate rule runs more than once.

The **playground** linked at the top of this page gives you a `kind` cluster with Kyverno v1.19.1 running and **no policies installed**. Once it is up, `kubectl` is already pointed at it — the context is `kind-astro-ats-011-playground-0403` (Astrona prefixes the environment name with `astro-`). The `Try it` checkpoints in the parts below assume that environment is already running; they never repeat the startup command.
