# JSON Patches

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS011/tree/main/sections/section-080/module-01/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS011.git -c sections/section-080/module-01/playground
> astrona destroy ats-011-playground-080
> ```

Section 040 taught you to mutate a resource by describing the shape you wanted: write a fragment of YAML under `patchStrategicMerge`, and Kyverno merges it into the incoming object. That works beautifully right up to the moment you need something strategic merge simply has no vocabulary for — deleting a key, targeting "the container at index 0" rather than "the container named `app`", or appending to a list that might not exist yet.

For those jobs Kyverno exposes a second mutation mechanism: **`mutate.patchesJson6902`**, an implementation of RFC 6902 JSON Patch. Instead of a shape, you write an ordered list of operations — each one naming an exact location in the document with an RFC 6901 JSON Pointer, and an action to perform there. It is the difference between handing someone a photograph of the finished room and handing them a numbered list of instructions.

That precision comes with strictness. `patchStrategicMerge` mostly degrades gracefully when reality doesn't match your fragment; a JSON Patch operation aimed at a path that doesn't resolve can reject the whole admission request. Knowing exactly which operations are lenient about a missing path and which are not — and how to stop caring either way — is the real skill this module builds.

> [!NOTE]
> "JSON Patches" here means **RFC 6902 JSON Patch inside a `mutate` rule** — not `kyverno-json`, a separate project that applies Kyverno policies to arbitrary JSON and YAML payloads outside Kubernetes. Part 1 sets the two side by side, because the names collide and at least one popular study guide maps this competency to the other one.

## How this module is organised

1. **[Part 1 — RFC 6902 Operations and Pointer Paths](./course-01-json-patch-operations.md)** — the operation set, how a JSON Pointer addresses nested fields and array elements, the `-` append index, and a working `patchesJson6902` rule proven against real Pods.
2. **[Part 2 — Pointer Escaping and Missing Paths](./course-02-pointer-escaping-and-missing-paths.md)** — escaping `/` as `~1` inside a key name, and the three very different things `add`, `remove`, and `replace` do when the location you named is not there.
3. **[Part 3 — Guarded Removal and Safe Patch Design](./course-03-guarded-removal-and-safe-patches.md)** — the blast radius of a strict operation on a broad match, using `preconditions` so a destructive patch stops depending on which operation you chose, and why a patch list is applied as a unit.

## Learning objectives

After this module you can:

- Explain when `patchesJson6902` is the right tool and when `patchStrategicMerge` is, and distinguish both from the separate `kyverno-json` project.
- Write a `mutate.patchesJson6902` rule using `add`, `remove`, and `replace` against correctly-formed JSON Pointer paths.
- Address an array element by index and the append position with `/-`, and predict what happens when the parent array is absent.
- Escape a literal `/` in an annotation or label key as `~1` (and `~` as `~0`) inside a JSON Pointer.
- Predict whether a given operation against a missing path is a silent no-op or a rejected admission request, and guard the rule with `preconditions` so the answer stops mattering.
- Explain why a JSON Patch list is applied atomically, and use that to reason about where a failure surfaces.

## Before you start

You should be comfortable writing a `mutate` rule with `patchStrategicMerge` and reading its effect on an admitted resource (Section 040), and be able to write a `preconditions` block with `all`/`any` condition entries (Section 020). Part 2 leans on both.

The linked lab gives you a `kind` cluster with Kyverno already installed and running. You will write the `patchesJson6902` rule yourself and prove it patches Pods that do and do not already carry the field you are targeting.

The **playground** linked at the top of this page gives you the same environment with nothing to submit: a single-node `kind` cluster with Kyverno v1.19.1 running and **no policies installed**. Once it is up, `kubectl` is already pointed at it — the context is `kind-astro-ats-011-playground-080` (Astrona prefixes the environment name with `astro-`). The `Try it` checkpoints in the parts below assume that environment is already running; they never repeat the startup command.
