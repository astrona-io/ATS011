# Deny Rules and the Condition Vocabulary

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS011/tree/main/sections/section-010/module-02/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS011.git -c sections/section-010/module-02/playground
> astrona destroy ats-011-playground-0102
> ```

Module 1 built validation as a **shape**: draw the resource you will accept, let Kyverno walk the real object against your drawing. That works for a huge class of requirements, and it stops working the moment the requirement is a *comparison* rather than a *shape*.

"No more than three replicas." "Every image must come from one of these two registries." "The value of this label must be one of these five." A pattern cannot say any of them, because none of them describes what the resource looks like — they describe a test the resource has to survive.

`validate.deny` is the other half of validation. Instead of a shape to match, you write **conditions**, and if they come out true the request is rejected. That inversion — pattern says what must be true to *pass*, deny says what must be true to *fail* — is the single most common source of backwards deny rules, and it is worth getting straight before writing one.

## How this module is organised

1. **[Part 1 — Deny Rules and the Inversion](./course-01-deny-rules-and-the-inversion.md)** — what `deny` is for, how its `conditions` block reads, the `any`/`all` distinction, why the polarity trips people up, and putting the offending value into the failure message.
2. **[Part 2 — The Condition Operator Vocabulary](./course-02-condition-operator-vocabulary.md)** — the full operator set, the four set operators and why there are four of them, numeric and duration comparisons, and running a `deny` once per list element with `foreach`.

## Learning objectives

After this module you can:

- Explain when a requirement needs `deny` rather than `pattern`, in terms of shape versus comparison.
- Write a `validate.deny` rule with a `conditions` block, and state correctly whether a true condition admits or rejects.
- Choose between `conditions.any` and `conditions.all` for a given requirement.
- Select the right operator from the full vocabulary, including the four set operators and the duration family.
- Combine `deny` with `foreach` to test every element of a list independently.
- Write a failure message that quotes the offending value back using `{{ }}` variables.

## Before you start

You need Module 1 of this section — `match`/`exclude`, `validationFailureAction`, and the idea of a rule body. You do not need Section 020 yet, though you will notice that a `deny.conditions` block and a `preconditions` block share the same `key`/`operator`/`value` syntax; that is deliberate, and Section 020 explains why the same vocabulary appears in two places with different meanings.

Some examples reference `{{ }}` variables and one uses a JMESPath function. Section 070 covers both properly; here, read `{{ request.object.spec.replicas }}` as "the replicas field of the incoming resource" and you will not be missing anything.

The **playground** linked at the top of this page gives you a `kind` cluster with Kyverno v1.19.1 running and **no policies installed**. Once it is up, `kubectl` is already pointed at it — the context is `kind-astro-ats-011-playground-0102` (Astrona prefixes the environment name with `astro-`). The `Try it` checkpoints in the parts below assume that environment is already running; they never repeat the startup command.
