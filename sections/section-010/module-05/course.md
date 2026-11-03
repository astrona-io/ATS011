# Assertion Trees and Manifest Verification

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS011/tree/main/sections/section-010/module-05/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS011.git -c sections/section-010/module-05/playground
> astrona destroy ats-011-playground-0105
> ```

A `pattern` describes what a resource should look like. A `deny` rule describes when to refuse a request. Both work well for simple checks, but some requirements need a calculation: "the sum of these two fields is at most 10", "no container image ends with `:latest`", "this list has exactly these three items".

Since Kyverno 1.13, `validate.assert` handles those cases. An assertion tree is a YAML structure in which each key can be a JMESPath expression (JMESPath is a query language for JSON). Kyverno evaluates the expressions against the resource and compares the results with the values you wrote.

A second validate subrule, `validate.manifests`, solves a different problem. It checks that a resource was signed by a trusted key before Kyverno admits it.

## How this module is organised

1. **[Part 1 — Assertion Trees](./course-01-assertion-trees.md)** — the `validate.assert` subrule, expressions in parentheses, iterating with `~.`, named bindings, the order in which Kyverno evaluates a tree, and how `assert` differs from `pattern`.
2. **[Part 2 — Validating Signed Manifests](./course-02-validating-signed-manifests.md)** — what `validate.manifests` checks, the `attestors`, `ignoreFields` and `dryRun` fields, and why this module's lab covers only the assertion tree. The part ends with the lab mission.

The module closes with a summary page and a mission, **Assertion Trees Lab**, a graded lab that asks you to write and apply the policies from this module on a live cluster.

## Learning objectives

After this module you can:

- Write a `validate.assert` rule with an `object` tree and a `message`.
- Explain what a key in parentheses does and why comparisons happen in the leaves of the tree.
- Check every element of a list with the `~.` modifier, and bind a value with `->name` to use it in a child check.
- Explain why the order of keys in a tree must not matter, and why a list written without `~.` must match exactly.
- Explain how `assert` differs from `pattern`, and choose between them.
- Describe the structure of a `validate.manifests` rule: `attestors`, `ignoreFields` and `dryRun`.

## Before you start

You need Module 1 of this section, which covers `match`, `validationFailureAction` and the shape of a rule. Modules 2 to 4 are not required.

The **playground** linked at the top of this page gives you a `kind` cluster with Kyverno v1.19.1 running and **no policies installed**. Once it is up, `kubectl` is already pointed at it — the context is `kind-astro-ats-011-playground-0105` (Astrona prefixes the environment name with `astro-`). The `Try it` checkpoints in the parts below assume that environment is already running; they never repeat the startup command.
