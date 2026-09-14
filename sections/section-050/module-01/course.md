# Generation Rules

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS011/tree/main/sections/section-050/module-01/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS011.git -c sections/section-050/module-01/playground
> astrona destroy ats-011-playground-050
> ```

Every rule you've written so far in this course reacts to a resource that a user or a controller already tried to create. Validation accepts or rejects it. A background scan reports on it after the fact. Neither one ever *makes* anything new. `generate` is different: it is the one rule type whose entire job is to create a brand-new downstream resource, on its own, the moment some other resource — classically a `Namespace` — comes into existence.

This is how a platform team stops asking every developer to remember "and also create a default NetworkPolicy" or "and also copy the shared registry credentials into your namespace." Those steps stop being a checklist item in a wiki page and become something that simply happens, guaranteed, for every namespace that will ever exist on the cluster from this point forward.

This module covers the two shapes a `generate` rule can take: writing a literal manifest yourself (`generate.data`), and copying an existing resource from somewhere else in the cluster (`generate.clone`), including the one setting — `synchronize: true` — that decides whether that copy stays a copy forever or becomes something Kyverno actively keeps identical to its source.

## How this module is organised

1. **[Part 1 — Generating from Literal Data](./course-01-generate-rule-anatomy-and-data.md)** — the `generate` rule shape, targeting `kind: Namespace` as the classic trigger, and `generate.data` for writing a manifest directly into the policy.
2. **[Part 2 — Cloning Resources and `synchronize`](./course-02-clone-and-synchronize.md)** — `generate.clone` for copying an existing resource, and the exact, empirically-verified behavior of `synchronize: true`: what propagates, what gets reverted, and what does not cascade the way you might assume.

## Learning objectives

After this module you can:

- Explain what triggers a `generate` rule and why `kind: Namespace` is its classic match target.
- Write a `generate.data` block that produces a literal manifest — such as a default-deny `NetworkPolicy` — into every new Namespace.
- Write a `generate.clone` block that copies an existing source resource — such as a shared `ConfigMap` — into every new Namespace.
- State precisely what `synchronize: true` does and does not guarantee: source-to-clone propagation, reversion of direct edits to the clone, and what actually happens (and why) when the trigger Namespace is deleted.

## Before you start

You should already be comfortable with a `ClusterPolicy`'s `match`/`exclude` block (Section 010) and ideally have seen `{{ }}` variable substitution used in a `message` (Section 010, Part 2) — this module uses that same syntax to reference the newly created Namespace's name.

The linked lab gives you a `kind` cluster with Kyverno already installed and running. You will write the `generate` rules yourself, then prove what actually gets created — and, in the capstone, prove `synchronize`'s behavior directly against a live cluster rather than taking it on faith.

The **playground** linked at the top of this page gives you the same environment with nothing to submit: a single-node `kind` cluster with Kyverno v1.19.1 running and **no policies installed**. Once it is up, `kubectl` is already pointed at it — the context is `kind-astro-ats-011-playground-050` (Astrona prefixes the environment name with `astro-`). The `Try it` checkpoints in the parts below assume that environment is already running; they never repeat the startup command.
