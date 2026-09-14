# Per-Element Mutation and Idempotency

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS011/tree/main/sections/section-040/module-02/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS011.git -c sections/section-040/module-02/playground
> astrona destroy ats-011-playground-0402
> ```

Module 1 mutated resources with `patchStrategicMerge`, and used the `(name)` anchor to reach every container with one fragment. That covers the case where every element gets the *same* change.

It does not cover the case where each element gets a *different* change — one derived from that element's own values. "Prefix every image with our mirror's hostname" is the standard example: each container ends up with a different image string, computed from the one it already had. A strategic-merge fragment has nowhere to put that computation.

`mutate.foreach` does. It is the same loop Section 010 used for validation, applied to a rule body that changes things instead of judging them, with the current element bound to `element`.

Which introduces a problem validation never had. A validate rule that runs twice reaches the same verdict twice. A mutate rule that runs twice applies its change twice — and mutate rules *do* run again, on every `UPDATE` to the resource. A rule that prefixes an image will cheerfully prefix an already-prefixed image, and the second half of this module is about why that happens and how to stop it.

## How this module is organised

1. **[Part 1 — foreach in a mutate rule](./course-01-foreach-in-mutate.md)** — per-element patches, referencing `element` to compute a value from the element itself, and how this differs from the `(name)` anchor.
2. **[Part 2 — Idempotency and Rule Interaction](./course-02-idempotency-and-rule-interaction.md)** — why a mutate rule runs again on UPDATE, the doubled-prefix failure that follows, guarding a `foreach` with `preconditions`, and what happens when two mutate rules touch the same field.

## Learning objectives

After this module you can:

- Write a `mutate.foreach` rule that patches each element of a list independently.
- Reference `element` to compute a patched value from the element's existing value.
- Explain when `foreach` is required and when the `(name)` anchor is sufficient.
- Explain why a mutate rule is re-evaluated on UPDATE and what that means for rules that transform an existing value.
- Diagnose a doubled or repeatedly-applied mutation, and fix it with a `preconditions` guard inside the `foreach`.
- Reason about two mutate rules that touch the same field, and restructure them so ordering stops mattering.

## Before you start

You need Module 1 of this section: `patchStrategicMerge`, the `(name)` anchor, and the rule that every mutate rule on the cluster runs before any validate rule. Section 010's `foreach` is useful background but not required — the loop mechanics are re-explained here because the rule body is different.

Section 020's `preconditions` appear in Part 2, in a position you may not have seen them: nested *inside* a `foreach` entry rather than at rule level.

The **playground** linked at the top of this page gives you a `kind` cluster with Kyverno v1.19.1 running and **no policies installed**. Once it is up, `kubectl` is already pointed at it — the context is `kind-astro-ats-011-playground-0402` (Astrona prefixes the environment name with `astro-`). The `Try it` checkpoints in the parts below assume that environment is already running; they never repeat the startup command.
