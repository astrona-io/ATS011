# Preconditions

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS011/tree/main/sections/section-020/module-01/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS011.git -c sections/section-020/module-01/playground
> astrona destroy ats-011-playground-020
> ```

Section 010 taught you two decisions every validate rule makes: `match`/`exclude` decides *which* resources a rule looks at, and `validate.pattern` decides *whether* a resource passes. Most real policies need a third decision wedged between those two: *should this rule's body even run for this specific resource that already matched?* That's what `preconditions` is for — a finer-grained, value-aware gate that sits between `match` and the rule body, evaluating `any`/`all` lists of conditions against the live request rather than the resource's static identity.

This module covers the `preconditions` block itself — its shape, its operators, and the two `key` expressions (`request.operation` and resource fields) that do most of the work in real policies — and then draws the line between `preconditions` and `match`/`exclude`, since the two tools overlap more than they first appear to.

## How this module is organised

1. **[Part 1 — The Preconditions Block and Its Operators](./course-01-preconditions-and-operators.md)** — the `preconditions.all`/`any` shape, the full operator vocabulary (`Equals`, `NotEquals`, `AnyIn`/`AllIn`/`AnyNotIn`/`AllNotIn`, numeric and duration comparisons), and referencing `request.operation` and `request.object` fields inside a `key`.
2. **[Part 2 — Preconditions vs. match/exclude, and all vs. any](./course-02-preconditions-vs-match.md)** — where `match`/`exclude`'s vocabulary genuinely runs out (and where it surprisingly doesn't), and the difference in behavior between `preconditions.all` (AND) and `preconditions.any` (OR).

## Learning objectives

After this module you can:

- Explain what a precondition actually does when it evaluates `false`: the rule body is skipped entirely, not merely passed.
- Write a `preconditions.all`/`any` block using the correct operator for a given comparison (`Equals`, `NotEquals`, the `*In` family, numeric, and duration operators).
- Reference `request.operation` to scope a rule to specific admission verbs (e.g., `CREATE` only), and reference a resource's own fields via `request.object` inside a condition's `key`.
- Identify which conditions `match`/`exclude` can already express on their own (label equality, operation filtering, namespace/name globs) and which ones require `preconditions` (any condition needing a `{{ }}` variable, a numeric comparison, or a value drawn from the resource body beyond its identity metadata).
- Predict the behavioral difference between `preconditions.all` and `preconditions.any` on a given policy, and recognize when a rule is unintentionally too loose (`any` where `all` was meant) or too strict (the reverse).

## Before you start

You should be comfortable with everything from Section 010 — `match`/`exclude`, `validate.pattern`, and `Enforce`/`Audit` — since this module builds directly on top of that rule anatomy rather than replacing any of it.

The linked lab gives you a `kind` cluster with Kyverno already installed and running. You will write a `ClusterPolicy` whose rule is exempted by a precondition for resources carrying a specific signal, then prove the exemption actually skips the check rather than just passing it.

The **playground** linked at the top of this page gives you the same environment with nothing to submit: a single-node `kind` cluster with Kyverno v1.19.1 running and **no policies installed**. Once it is up, `kubectl` is already pointed at it — the context is `kind-astro-ats-011-playground-020` (Astrona prefixes the environment name with `astro-`). The `Try it` checkpoints in the parts below assume that environment is already running; they never repeat the startup command.
