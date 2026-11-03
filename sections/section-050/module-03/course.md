# Cloning Several Resources and generate foreach

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS011/tree/main/sections/section-050/module-03/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS011.git -c sections/section-050/module-03/playground
> astrona destroy ats-011-playground-0503
> ```

A `generate.clone` rule copies exactly one source object. Real platforms need more: every new team namespace should receive the shared ConfigMaps and the registry Secret, not just one of them. And sometimes the number of things to create is not fixed by the rule at all, but by the trigger, for example one object per environment named in an annotation.

Kyverno has a tool for each case. `cloneList` clones many source objects in one rule, chosen by kind and by label. `generate.foreach` loops over a list and generates one resource per element.

## How this module is organised

1. **[Part 1 — cloneList: Cloning Many Sources](./course-01-clonelist.md)** — the `kinds`, `namespace` and `selector` fields, and how they decide which source objects are copied.
2. **[Part 2 — generate foreach: One Resource per Element](./course-02-generate-foreach.md)** — looping over a list, the `element` variable, per-iteration `context` and `preconditions`, and the generate fields each element supplies. The part ends with the module lab.

The module closes with a summary page and a mission, **cloneList and generate foreach Lab**, a graded lab that asks you to write and apply the policies from this module on a live cluster.

## Learning objectives

After this module you can:

- Write a `cloneList` rule that copies several kinds from a source namespace into a new namespace.
- Use a `selector` to clone only the source objects that opt in with a label.
- Write a `generate.foreach` rule that creates one resource per element of a list.
- Use `element`, `elementIndex`, `context` and `preconditions` inside a foreach.
- Decide whether a task needs `clone`, `cloneList`, `data` or `foreach`.

## Before you start

You need Modules 1 and 2 of this section: `generate.data`, `generate.clone`, `synchronize`, and the fact that the background controller needs RBAC for every kind it creates.

The **playground** linked at the top of this page gives you a `kind` cluster with Kyverno v1.19.1 running, **no policies installed**, and a source namespace `shared-config` that holds ConfigMaps and a Secret to clone. Once it is up, `kubectl` is already pointed at it — the context is `kind-astro-ats-011-playground-0503`. The `Try it` checkpoints assume it is running.
