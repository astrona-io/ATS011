# Context Beyond apiCall

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS011/tree/main/sections/section-070/module-02/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS011.git -c sections/section-070/module-02/playground
> astrona destroy ats-011-playground-0702
> ```

Module 1 of this section introduced `context` as the place a rule fetches data before it runs, and then spent its time on one entry type: `apiCall`, which queries the Kubernetes API during admission.

`apiCall` is the most general of the context types and the one the exam leans on hardest, but it is one of four, and reaching for it when another fits is a common way to make a policy slower and more brittle than it needs to be. A registry allowlist does not need an API query — it needs a ConfigMap. A check on an image's architecture cannot use an API query at all, because the Kubernetes API does not know what is inside an image.

This module covers the other three: `configMap` for operational data you want to change without editing policies, `variable` for computing and naming an intermediate value, and `imageRegistry` for data that lives in a container registry rather than in your cluster. It closes with `globalReference`, which exists because an `apiCall` made on every single admission request is a cost you can sometimes avoid paying.

## How this module is organised

1. **[Part 1 — configMap and variable](./course-01-configmap-and-variable-context.md)** — externalising policy data into a ConfigMap so the policy itself stops changing, the `variable` entry type for naming intermediate results, and how context entries build on one another in order.
2. **[Part 2 — imageRegistry and globalReference](./course-02-imageregistry-and-globalreference.md)** — reading real image metadata from a registry at admission time, what the result actually contains, and caching expensive lookups in a `GlobalContextEntry` instead of repeating them per request.

## Learning objectives

After this module you can:

- Choose the right context entry type for a given requirement, and say why `apiCall` is not always it.
- Read policy data from a ConfigMap with a `configMap` context entry, and explain what changes when the ConfigMap changes.
- Use a `variable` entry to compute an intermediate value and reference it from a condition or a message.
- Explain how context entries are ordered and why a later entry can reference an earlier one.
- Fetch image metadata with an `imageRegistry` entry and name the fields its result contains.
- Say what a `GlobalContextEntry` is for and when a cached lookup beats a per-request one.

## Before you start

You need Module 1 of this section: `{{ }}` variables, JMESPath basics, the `context` block, and `context.apiCall`. Section 010 Module 2's `deny` conditions appear throughout, since a fetched value is most often used in a condition.

The `imageRegistry` examples need the cluster to have outbound access to a public registry — the lookup is a real network call made during admission, not something cached from the image pull.

The **playground** linked at the top of this page gives you a `kind` cluster with Kyverno v1.19.1 running and **no policies installed**, plus a `policy-config` namespace holding an `allowed-registries` ConfigMap for the `configMap` context examples. Once it is up, `kubectl` is already pointed at it — the context is `kind-astro-ats-011-playground-0702` (Astrona prefixes the environment name with `astro-`). The `Try it` checkpoints in the parts below assume that environment is already running; they never repeat the startup command.
