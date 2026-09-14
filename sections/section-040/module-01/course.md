# Mutation Rules

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS011/tree/main/sections/section-040/module-01/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS011.git -c sections/section-040/module-01/playground
> astrona destroy ats-011-playground-040
> ```

Every rule in Section 010 answered the same question: does this resource look right? A `validate` rule can only ever say yes or no. It cannot fix anything — it has no mechanism for changing the object in front of it, only for accepting or rejecting it as-is. That's a real limitation. If every team's Pods are supposed to carry `imagePullPolicy: IfNotPresent`, you have two options with `validate` alone: reject every Pod that gets it wrong (and make every developer edit their manifest and retry), or silently let it slide. Neither one actually *fixes* the Pod.

Kyverno's `mutate` rule is the other half of the picture. Instead of describing a shape a resource must already have, it describes a shape to *apply* — a patch that Kyverno merges into the resource before the API server ever persists it. A `validate` rule is a gate; a `mutate` rule is a rewrite.

This module covers the two mechanisms that do that rewriting, and one guarantee about how they interact with everything else in this course:

1. **[Part 1 — patchStrategicMerge and Ordering](./course-01-patchstrategicmerge-mechanics.md)** — how `mutate.patchStrategicMerge` merges a patch fragment into an incoming resource using Kubernetes' own strategic-merge-patch rules (not plain JSON patch), the `(name)` anchor that makes a patch reach every element of a list instead of just the first, what actually happens when the incoming resource already sets a conflicting value, and the guarantee that every mutate rule on the cluster finishes before any validate rule ever runs.
2. **[Part 2 — Mutating Existing Resources](./course-02-mutating-existing-resources.md)** — `mutate.mutateExistingOnPolicyUpdate` and `mutate.targets`, which let a mutate rule reach backward and patch resources that already exist, triggered by the *policy* being created or updated rather than by a new admission request to the resource itself — plus the RBAC grant this requires in practice, and the real, occasionally surprising limits on what an already-existing resource can have changed on it.

## Learning objectives

After this module you can:

- Write a `mutate.patchStrategicMerge` block that injects or overrides a label, annotation, or container-level field on every incoming resource.
- Explain why a list under `patchStrategicMerge` needs the `(name)` anchor to reach every element, and what breaks when it's missing.
- State, from direct observation, what happens when an incoming resource already sets a value that a mutate rule also sets.
- Explain why a `validate` rule can rely on a field that an earlier mutate rule injects in the very same admission request, and why that ordering is a guarantee, not a coincidence of rule-naming.
- Configure `mutateExistingOnPolicyUpdate` with a `targets` block to retroactively patch resources that predate the policy, and identify the RBAC grant Kyverno requires before it will even accept such a policy.
- Recognize the real limits of mutating an already-existing resource — which fields Kubernetes will actually let an admission controller change after the fact, and which it won't, regardless of what your `patchStrategicMerge` says.

## Before you start

You should be comfortable with everything from Section 010 (writing a `ClusterPolicy`, `match`/`exclude`, reading a `kubectl apply` rejection) — this module assumes that vocabulary and builds the mutation side of it on top.

The linked lab gives you a `kind` cluster with Kyverno already installed and running. You will write the `ClusterPolicy` yourself, then prove the mutation actually lands in the persisted object — not just that `kubectl apply` succeeded.

The **playground** linked at the top of this page gives you the same environment with nothing to submit: a single-node `kind` cluster with Kyverno v1.19.1 running and **no policies installed**, plus two Pods already running in the `legacy` namespace that predate anything you apply. Once it is up, `kubectl` is already pointed at it — the context is `kind-astro-ats-011-playground-040` (Astrona prefixes the environment name with `astro-`). The `Try it` checkpoints in the parts below assume that environment is already running; they never repeat the startup command.
