# Attestors, Digests, and Registry Access

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS011/tree/course/full-curriculum/sections/section-060/module-02/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS011.git -c sections/section-060/module-02/playground
> astrona destroy ats-011-playground-0602
> ```

Module 1 verified one signature against one public key, which is the shape almost every `verifyImages` example uses and almost no production policy stops at.

Real supply-chain requirements are rarely "signed by this key". They are "signed by our CI, *and* countersigned by the security team". Or "signed by a GitHub Actions workflow in our organisation" — where there is no long-lived key at all, only a short-lived certificate tied to an identity. Or "images from our own registry must be signed, images from upstream may pass unsigned". Or, most often, "that registry needs credentials Kyverno does not have."

Each of those is a field on the rule you already know. This module is about the fields Module 1 left at their defaults.

## How this module is organised

1. **[Part 1 — Attestor Structures and Trust Material](./course-01-attestor-structures.md)** — the `attestors` list and its `count`, how multiple attestor blocks compose into an AND while entries inside one compose into an M-of-N, and the three kinds of trust material an entry can carry: a public key, a certificate, and a keyless identity.
2. **[Part 2 — Digests, Scope, and Registry Access](./course-02-digests-scope-and-registry-access.md)** — `mutateDigest` versus `verifyDigest`, narrowing with `skipImageReferences`, making verification advisory with `required`, supplying registry credentials, and what a rule does when the registry cannot be reached at all.

## Learning objectives

After this module you can:

- Read an `attestors` block and say how many independent signatures a given image must carry to satisfy it.
- Explain how `count` turns a list of entries into an M-of-N requirement, and what omitting it means.
- Distinguish key-based, certificate-based, and keyless attestors, and name what a keyless entry matches on instead of a key.
- Choose between `mutateDigest` and `verifyDigest` for a given requirement, and say which one changes the persisted resource.
- Narrow a rule with `skipImageReferences` and relax it with `required: false`, and predict the effect of each on an unsigned image.
- Explain what happens to admission when the registry is unreachable, and how that interacts with the webhook's failure policy.

## Before you start

You need Module 1 of this section: the `verifyImages` rule shape, `imageReferences`, a single key-based attestor, and the fact that verification runs in Kyverno's *mutating* webhook. Section 070's `imageRegistry` context type is useful background for Part 2 but is not required.

Verification is a live network call to a registry during admission, so the checkpoints need the cluster to have outbound access to `ghcr.io`. Where a concept cannot be demonstrated against a public demo image, the text says so rather than inventing a command.

The **playground** linked at the top of this page gives you a `kind` cluster with Kyverno v1.19.1 running and **no policies installed**. Once it is up, `kubectl` is already pointed at it — the context is `kind-astro-ats-011-playground-0602` (Astrona prefixes the environment name with `astro-`). The `Try it` checkpoints in the parts below assume that environment is already running; they never repeat the startup command.
