# Pattern-Based Validation

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS011/tree/main/sections/section-010/module-01/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS011.git -c sections/section-010/module-01/playground
> astrona destroy ats-011-playground-010
> ```

Kubernetes' API server will happily accept a Pod with no resource limits, no owner label, and a `:latest` image tag. Nothing in the base cluster stops it — the schema for a Pod is satisfied, and the schema doesn't know about your organization's rules. Kyverno closes that gap with a `ValidatingAdmissionPolicy`-style webhook that you configure entirely in YAML: a `ClusterPolicy` with one or more `validate` rules, each describing the shape a resource must match before the API server is allowed to persist it.

This module covers the two building blocks of every validation rule: the `pattern` block that shapes a single accepted structure, and the surrounding rule anatomy (`match`, `validationFailureAction`, `message`) that decides which resources the rule even looks at and what happens when a resource fails.

## How this module is organised

1. **[Part 1 — The ClusterPolicy Object and Its Audience](./course-01-the-clusterpolicy-object.md)** — the policy as an ordinary Kubernetes resource, `ClusterPolicy` versus `Policy`, and how `match` and `exclude` decide which resources a rule even considers.
2. **[Part 2 — The Pattern Block and What Failure Costs](./course-02-the-pattern-block-and-failure-actions.md)** — describing a shape rather than writing a test, the wildcard and conditional-operator vocabulary, and the separate decision of whether a violation blocks a request or merely lands in a report.
3. **[Part 3 — anyPattern, foreach & Failure Messages](./course-03-anypattern-foreach-and-messages.md)** — expressing a choice between shapes, validating every element of a list, and writing a message a developer can act on.

## Learning objectives

After this module you can:

- Explain how a `validate.pattern` block is matched against an incoming resource, field by field.
- Use the `?` and `*` wildcard operators, and conditional operators like `>=` and `!-`, inside a pattern.
- Choose `Enforce` to block a non-compliant resource outright, or `Audit` to allow it while recording a `PolicyReport` entry.
- Write an `anyPattern` block so a resource is accepted if it matches *any* one of several shapes.
- Use `foreach` to validate every element of a list field (such as a Pod's `containers`) independently.

## Before you start

You should be comfortable reading and writing plain Kubernetes YAML (Pods, Deployments, `kubectl apply`), and know the basic verbs `kubectl get` / `describe` / `logs`.

The linked lab gives you a `kind` cluster with Kyverno already installed and running. You will write the `ClusterPolicy` yourself, then prove it works against both a Pod that violates it and one that satisfies it.

The **playground** linked at the top of this page gives you the same environment with nothing to submit: a single-node `kind` cluster with Kyverno v1.19.1 running and **no policies installed**. Once it is up, `kubectl` is already pointed at it — the context is `kind-astro-ats-011-playground-010` (Astrona prefixes the environment name with `astro-`). The `Try it` checkpoints in the parts below assume that environment is already running; they never repeat the startup command.
