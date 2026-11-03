# The images Variable and Image Extraction

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS011/tree/course/full-curriculum/sections/section-060/module-03/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS011.git -c sections/section-060/module-03/playground
> astrona destroy ats-011-playground-0603
> ```

The earlier modules of this section verified signatures. Signature checks are one use of image data. Many policies need less: they only need to know *which* image a workload uses. Is it from an approved registry? Does it use the `latest` tag? Is it pinned by digest?

Kyverno answers these questions without any registry access. For every Pod and every pod controller it builds a context variable called `images`, which splits each image reference into registry, path, name, tag and digest. A rule reads those parts with ordinary JMESPath. For resources that are not Pods, such as a custom resource that holds an image in some field, you tell Kyverno where to look with `imageExtractors`.

## How this module is organised

1. **[Part 1 — The images Variable](./course-01-the-images-variable.md)** — the structure of `images`, the fields of each entry, JMESPath queries over it, and how the same rule works on a Pod and on a Deployment.
2. **[Part 2 — Image Extractors](./course-02-image-extractors.md)** — what the default extraction covers, how `imageExtractors` finds images in custom resources, and how the two combine in a rule.

The module closes with a summary page and a mission, **Image Extraction Lab**, a graded lab that asks you to write and apply the policies from this module on a live cluster.

## Learning objectives

After this module you can:

- Describe the three groups inside `images` and say how an entry is keyed.
- Name the fields of an image entry and say what Kyverno fills in when the reference omits the registry or the tag.
- Write a JMESPath query that returns one field from every container in a Pod.
- Write a `deny` rule that blocks images from an unapproved registry or with the `latest` tag.
- Explain why one rule covers both a Pod and a Deployment.
- Say when `imageExtractors` is needed and write an entry with `path`, `name`, `value` and `key`.

## Before you start

You need the rule basics from earlier sections: `match`, `validate.deny` with `conditions`, and JMESPath substitution with `{{ }}`. You do not need the signature material from the first two modules of this section, and nothing here needs access to a registry.

The **playground** linked at the top of this page gives you a `kind` cluster with Kyverno v1.19.1 running and **no policies installed**. Once it is up, `kubectl` is already pointed at it — the context is `kind-astro-ats-011-playground-0603` (Astrona prefixes the environment name with `astro-`). The `Try it` checkpoints in the parts below assume that environment is already running; they never repeat the startup command.
