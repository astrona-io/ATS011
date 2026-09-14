# Policy Objects and Rule Anatomy

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS011/tree/main/sections/section-000/module-01/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS011.git -c sections/section-000/module-01/playground
> astrona destroy ats-011-playground-000
> ```

Every other section of this course teaches one *rule type* — validate, mutate, generate, verifyImages, cleanup. This one teaches the thing they all live inside: the **policy object** itself.

That matters because several decisions are made at the policy level rather than the rule level, and they are easy to miss when you learn rule types one at a time. Which kind you chose (`ClusterPolicy` or `Policy`) decides what the rules can reach. `validationFailureActionOverrides` decides whether one namespace gets blocked while another only gets reported. And when several policies match the same request, the order the rule types run in is fixed by Kyverno, not by you — which explains behaviour that otherwise looks like a race.

None of these is a separate competency on the KCA's Writing Policies list, which is exactly why they tend to fall through the gaps: every one of them can show up attached to a question about validation, mutation, or generation.

## How this module is organised

1. **[Part 1 — Policy Objects and Rule Anatomy](./course-01-policy-objects-and-rule-anatomy.md)** — the two policy kinds and what scope really changes, the fields every rule carries whatever its type, and the order in which scope, `match`, `context`, and `preconditions` are consulted.
2. **[Part 2 — Failure Actions and Staged Rollout](./course-02-failure-actions-and-rollout.md)** — `validationFailureAction` at policy level, `failureAction` per rule, and `validationFailureActionOverrides` for enforcing in one namespace while auditing elsewhere.
3. **[Part 3 — Rule Ordering and Carving Out Exceptions](./course-03-rule-ordering-and-exceptions.md)** — the fixed order Kyverno runs rule types in and why it is not configurable, how several policies compose on one request, and the three ways to exempt something from a rule without weakening it for everyone.

## Learning objectives

After this module you can:

- Choose between `ClusterPolicy` and `Policy` for a given requirement, and state what a namespaced policy cannot do.
- Name the fields every rule has regardless of its type, and where each one is evaluated.
- Set `validationFailureAction` at policy level and `failureAction` at rule level, and explain why the per-rule form exists.
- Use `validationFailureActionOverrides` to enforce a rule in some namespaces while auditing it in others.
- Predict which rule type runs first when one request is matched by several policies.
- Choose between `exclude`, `preconditions`, and a `PolicyException` when one workload needs to be exempt from a rule.

## Before you start

You should be able to read Kubernetes YAML and run `kubectl apply` / `get` / `describe`. No prior Kyverno knowledge is assumed — this module is the on-ramp, and every other section builds on the vocabulary it establishes.

This is a **primer**, not one of the eleven Writing Policies competencies. It exists because the topics it covers have no natural home in a rule-type-shaped curriculum, yet turn up attached to questions about every rule type.

The **playground** linked at the top of this page gives you a `kind` cluster with Kyverno v1.19.1 running, **no policies installed**, and two empty namespaces (`team-prod`, `team-staging`) so one policy can behave differently in each. Once it is up, `kubectl` is already pointed at it — the context is `kind-astro-ats-011-playground-000` (Astrona prefixes the environment name with `astro-`). The `Try it` checkpoints in the parts below assume that environment is already running; they never repeat the startup command.
