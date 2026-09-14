# The CEL-Native Policy Family

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS011/tree/course/110-module-02/sections/section-110/module-02/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS011.git -c sections/section-110/module-02/playground
> astrona destroy ats-011-playground-1102
> ```

Module 1 ended with `ValidatingPolicy` and the observation that it belongs to a family. That family is the answer to a question the module raised but did not settle: if CEL replaces JMESPath for validation, what happens to mutation, generation, image verification, and cleanup?

Each gets its own kind. Where a classic `ClusterPolicy` is one resource holding rules of five different types, `policies.kyverno.io` splits them apart — `ValidatingPolicy`, `MutatingPolicy`, `GeneratingPolicy`, `ImageValidatingPolicy`, and `DeletingPolicy`, each with a `Namespaced*` counterpart.

That is a genuine design change, not a rename. A `ClusterPolicy` can carry a mutate rule and a validate rule that interact, in a fixed order, inside one object; the new family cannot, because they are different objects. This module is about what each kind does, what the split buys, and what it costs.

## How this module is organised

1. **[Part 1 — MutatingPolicy and GeneratingPolicy](./course-01-mutating-and-generating-policies.md)** — CEL-native mutation with `mutations` and JSON Patch or apply-configuration style, generation with `generate` expressions, and how the one-kind-per-job split changes rules that used to share a policy.
2. **[Part 2 — ImageValidatingPolicy and DeletingPolicy](./course-02-imagevalidating-and-deletingpolicy.md)** — signature verification expressed in CEL, the cleanup successor the `ClusterCleanupPolicy` deprecation warning points at, and a map from every classic rule type to its CEL-native kind.

## Learning objectives

After this module you can:

- Name the five kinds in the `policies.kyverno.io` family and the classic rule type each one replaces.
- Explain what the one-kind-per-job split gains and what it makes harder, compared with a single `ClusterPolicy` holding several rule types.
- Read a `MutatingPolicy` and say what it changes and when it runs.
- Recognise a `GeneratingPolicy` and a `DeletingPolicy`, and connect the latter to the deprecation warning from Section 100.
- Identify which family a policy object belongs to from its `apiVersion` alone, and predict the shape of the rejection message it produces.

## Before you start

You need Module 1 of this section — CEL itself, `matchConstraints`, `validationActions`, and the `ValidatingPolicy` shape, which every kind here echoes. Sections 040, 050, 060 and 100 supply the classic counterparts each kind replaces; you will get more from this module having met them, but the text names what each one did rather than assuming you remember.

These kinds are newer than the `ClusterPolicy` equivalents, and this module marks clearly which behaviour was observed on a live v1.19.1 cluster and which is read from the resource schema.

The **playground** linked at the top of this page gives you a `kind` cluster with Kyverno v1.19.1 running and **no policies installed**. Once it is up, `kubectl` is already pointed at it — the context is `kind-astro-ats-011-playground-1102` (Astrona prefixes the environment name with `astro-`). The `Try it` checkpoints in the parts below assume that environment is already running; they never repeat the startup command.
