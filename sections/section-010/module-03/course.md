# Validation Anchors

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS011/tree/main/sections/section-010/module-03/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS011.git -c sections/section-010/module-03/playground
> astrona destroy ats-011-playground-0103
> ```

A `validate.pattern` is a shape, and Module 1 used it the simple way: every field you name must be present and must match. That gets you a long way, and then you hit a requirement that is conditional.

"A container using a `:latest` image must set `imagePullPolicy: Always`" — but a container using a pinned tag may set whatever it likes. "`hostPath` volumes are forbidden" — but a Pod with no volumes at all is fine. "At least one container needs a readiness probe" — not all of them.

None of those is expressible by naming fields, because each one needs the pattern to *decide* whether a check applies before applying it. **Anchors** are how a pattern carries that decision. They are punctuation wrapped around a key — `(image)`, `=(volumes)`, `^(containers)`, `X(hostPath)`, `<(image)` — and each one changes what the pattern does with the fields around it.

There are five, they are easy to confuse, and the exam expects you to tell them apart.

## How this module is organised

1. **[Part 1 — Conditional and Equality Anchors](./course-01-conditional-and-equality-anchors.md)** — `()` for "if this matches, then check the siblings", `=()` for "if this key exists, check inside it", and the skip-versus-fail distinction that both depend on.
2. **[Part 2 — Existence, Negation, and Global Anchors](./course-02-existence-negation-and-global-anchors.md)** — `^()` for "at least one element", `X()` for "this key must not exist", `<()` for gating the whole rule, and a decision table for choosing between all five.

## Learning objectives

After this module you can:

- Explain why a plain pattern cannot express a conditional requirement, and which anchor supplies each kind of condition.
- Write a conditional anchor `()` and predict, for a given resource, whether its sibling fields are enforced or skipped.
- Use `=()` to check inside an optional block without requiring the block to exist.
- Use `^()` to require that at least one list element matches, and say how that differs from a plain list pattern.
- Use `X()` to forbid a field outright, and `<()` to skip an entire rule when a condition does not hold.
- Read a validation failure path and work out which anchor produced it.

## Before you start

You need Module 1 of this section: `validate.pattern`, the wildcard vocabulary (`*`, `?*`, `|`), and the fact that a plain list pattern is matched by position. Module 2 is not required, though you will notice that anchors and `deny` conditions are two different answers to the same problem, and Part 2 ends by saying when to reach for which.

Section 040 uses one anchor — `(name)` — on the mutation side. The syntax is identical there; the semantics differ, because a mutate pattern applies a change rather than asserting a shape.

The **playground** linked at the top of this page gives you a `kind` cluster with Kyverno v1.19.1 running and **no policies installed**. Once it is up, `kubectl` is already pointed at it — the context is `kind-astro-ats-011-playground-0103` (Astrona prefixes the environment name with `astro-`). The `Try it` checkpoints in the parts below assume that environment is already running; they never repeat the startup command.
