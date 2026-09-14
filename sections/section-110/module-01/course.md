# CEL in Kyverno Policies

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS011/tree/main/sections/section-110/module-01/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS011.git -c sections/section-110/module-01/playground
> astrona destroy ats-011-playground-110
> ```

Ten sections of this course have taught you to describe resources by shape. `validate.pattern` is a YAML fragment with wildcards; `patchStrategicMerge` is a YAML fragment to merge; anchors let a shape reach conditionally into lists. That approach is genuinely good at what it is good at — most policies really are shape assertions, and a pattern reads closer to the resource it governs than any expression language would.

It has a ceiling, though, and you can feel exactly where. A shape cannot compare two fields to each other. It cannot do arithmetic on a quantity. It cannot say "at least two of these must hold" or "this value may only ever increase." For those you need to *evaluate* something, not *match* something.

**CEL — the Common Expression Language — is the evaluation language Kubernetes settled on.** It is small, sandboxed, and deliberately not Turing-complete: every expression terminates, and the API server can bound its cost before running it. It is already what backs CRD `x-kubernetes-validations` and the built-in `ValidatingAdmissionPolicy` type. Kyverno adopting it means your Kyverno expressions and your upstream Kubernetes expressions are the same language.

Kyverno gives you CEL in two places that look similar and are architecturally quite different. Inside a `ClusterPolicy`, `validate.cel` is a drop-in replacement for `validate.pattern` on a single rule — everything else about the policy stays as you know it. Separately, the `policies.kyverno.io` API group introduces `ValidatingPolicy`, `MutatingPolicy`, `GeneratingPolicy`, `ImageValidatingPolicy`, and `DeletingPolicy`: a parallel family where CEL is the only expression language and the resource shape mirrors Kubernetes' own `ValidatingAdmissionPolicy` rather than Kyverno's classic one. That family is what every `ClusterPolicy is deprecated` warning in this course has been pointing at.

## How this module is organised

1. **[Part 1 — CEL as a Language](./course-01-cel-as-a-language.md)** — what CEL is and why it is deliberately not Turing-complete, the values Kyverno binds (`object`, `oldObject`, `request`, `variables`, `namespaceObject`), the macros that matter for Kubernetes resources, and the fact that expressions are type-checked against the matched kind before any resource is submitted.
2. **[Part 2 — Writing a validate.cel Rule Safely](./course-02-writing-validate-cel-safely.md)** — the two failure modes that both look like a working policy: an unguarded field access that errors instead of returning false, and a rule that makes Pods undeletable because `object` is null on DELETE.
3. **[Part 3 — The ValidatingPolicy Type](./course-03-the-validatingpolicy-type.md)** — the `policies.kyverno.io` family the deprecation warnings point at, `matchConstraints` versus `match`, `validationActions`, and `matchConditions` as a separate applicability gate.
4. **[Part 4 — Autogen and Native Admission Policies](./course-04-autogen-and-native-admission-policies.md)** — Section 090's autogen carried into CEL expressions, and compiling a policy into a real Kubernetes `ValidatingAdmissionPolicy` so the API server enforces it with no webhook in the path.

## Learning objectives

After this module you can:

- Explain what CEL is, why Kubernetes chose a non-Turing-complete expression language, and when a CEL expression is a better fit than a `validate.pattern`.
- Name the values Kyverno binds into an expression, say which one makes before-and-after rules possible, and state when a `variables` entry is evaluated relative to the expressions using it.
- Read the type-check warning Kyverno prints at apply time and connect it to the admission failure it predicts.
- Guard optional field access with `has()`, and explain why `has()` alone does not stop a rule from making Pods undeletable.
- Write a `ValidatingPolicy` with `matchConstraints`, `validations`, and `validationActions`, map each to the `ClusterPolicy` concept it replaces, and pre-filter requests with `matchConditions`.
- Enable `ValidatingAdmissionPolicy` generation, name the two objects it produces, and identify from a rejection message alone whether Kyverno's webhook or the API server blocked a request.

## Before you start

You should be able to write a `validate.pattern` rule with `match`/`exclude` and understand `Enforce` versus `Audit` (Section 010), and know what autogen does to a Pod-matching rule (Section 090) — Part 2 shows the CEL equivalent. Familiarity with `PolicyReport` objects from Section 030 helps when you reach `validationActions: [Audit]`.

No prior CEL experience is assumed. If you have written a JMESPath `{{ }}` variable in Section 070, you already have the right instincts; CEL is a different language with different syntax, and the module introduces it from scratch rather than by analogy.

The linked lab gives you a `kind` cluster with Kyverno already installed and running.

The **playground** linked at the top of this page gives you the same environment with nothing to submit: a single-node `kind` cluster with Kyverno v1.19.1 running and **no policies installed**. Once it is up, `kubectl` is already pointed at it — the context is `kind-astro-ats-011-playground-110` (Astrona prefixes the environment name with `astro-`). The `Try it` checkpoints in the parts below assume that environment is already running; they never repeat the startup command.
