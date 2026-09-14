# Variables & API Calls in Policies

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS011/tree/main/sections/section-070/module-01/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS011.git -c sections/section-070/module-01/playground
> astrona destroy ats-011-playground-070
> ```

Every policy so far in this course has been static: a `pattern`, an `anyPattern`, a `foreach`, a `preconditions` block — all of them compare the incoming resource against values you typed directly into the YAML. That covers a huge amount of real policy, but it has a hard ceiling. Some decisions genuinely cannot be made from the resource alone: "does this namespace already have too many Pods?", "does the image this Pod requests actually exist in the registry?", "what does the ConfigMap that defines our approved list currently say?" None of those questions can be answered by looking only at the object being admitted — they require reaching outside the request, to the live state of the cluster (or beyond it), at the exact moment the rule runs.

Kyverno's answer is two features that work together: **variables**, written as `{{ }}` and resolved with JMESPath, which let a rule read data out of the admission request itself (the resource, its previous version on an UPDATE, who's making the request); and **`context.apiCall`**, which lets a rule fetch fresh data from the Kubernetes API — or any HTTP JSON service — and bind the result to a named variable before the rule body ever runs.

This module covers both, in the order you'll actually reach for them: variables first, since `context.apiCall` results are themselves just another variable once fetched, and then the API call mechanism itself, verified end-to-end against a real cluster.

## How this module is organised

1. **[Part 1 — JMESPath, Variables & Built-in Context](./course-01-jmespath-variables-and-context.md)** — the `{{ }}` syntax, where it is and isn't legal, JMESPath basics as Kyverno uses them, and the built-in request variables every policy author reaches for (`request.operation`, `request.userInfo`, `request.object` vs. `request.oldObject`).
2. **[Part 2 — context.apiCall & Live Cluster Data](./course-02-apicall-and-live-cluster-data.md)** — the `context.apiCall` block, its exact field shape, a real quota-style policy built from a live Pod count instead of a hardcoded number, and what happens — verified, not guessed — when the API call itself fails.

## Learning objectives

After this module you can:

- Write and read `{{ }}` variable expressions, and state precisely where Kyverno does and does not allow them.
- Use `request.object`, `request.oldObject`, `request.operation`, `request.namespace`, and `request.userInfo` to make a rule aware of the request, not just the resource.
- Add a `context.apiCall` entry to a rule that fetches data from the Kubernetes API and shapes the response with `jmesPath`.
- Build a `validate.deny.conditions` check that makes an admit/reject decision using a value that only exists at evaluation time — not one baked into the policy.
- Explain what happens to a rule when its own `context.apiCall` fails, and how `default` changes that outcome.

## Before you start

You should be comfortable with everything from Section 010 (pattern-based validation) and Section 020 (preconditions) — this module assumes you already know `match`/`exclude`, `validate.pattern`, `validate.deny.conditions`, and the `preconditions.any`/`all` shape, and builds the variable mechanics underneath all of them.

The linked labs give you a `kind` cluster with Kyverno already installed. You will write a `ClusterPolicy` that makes a real, live decision about the cluster's current state — not a decision Kyverno could have made just by looking at the pattern in your YAML file.

The **playground** linked at the top of this page gives you the same environment with nothing to submit: a single-node `kind` cluster with Kyverno v1.19.1 running and **no policies installed**, plus three Pods already running in the `team-a` namespace for a `context.apiCall` to count. Once it is up, `kubectl` is already pointed at it — the context is `kind-astro-ats-011-playground-070` (Astrona prefixes the environment name with `astro-`). The `Try it` checkpoints in the parts below assume that environment is already running; they never repeat the startup command.
