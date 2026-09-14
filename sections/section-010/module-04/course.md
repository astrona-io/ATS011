# The podSecurity Subrule

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS011/tree/main/sections/section-010/module-04/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS011.git -c sections/section-010/module-04/playground
> astrona destroy ats-011-playground-0104
> ```

Everything in this section so far has you writing the check yourself. A pattern, a deny condition, an anchor — you describe the requirement, Kyverno evaluates it.

The Pod Security Standards are different, because somebody has already written the requirements. The PSS are an upstream Kubernetes specification defining three profiles — `privileged`, `baseline`, `restricted` — each a fixed list of controls covering privilege escalation, host namespaces, capabilities, volume types, seccomp, and a dozen more. Reproducing `restricted` by hand in `validate.pattern` would take a few hundred lines of YAML, and would drift out of date every time Kubernetes revised the standard.

`validate.podSecurity` is a rule body that takes the profile by name instead:

```yaml
validate:
  podSecurity:
    level: baseline
    version: latest
```

Two lines, and the rule enforces the whole profile. The interesting work is not in writing that — it is in knowing what each level actually contains, how to exempt a single control without abandoning the profile, and how this relates to Kubernetes' own built-in Pod Security Admission.

## How this module is organised

1. **[Part 1 — Profiles, Levels, and Versions](./course-01-podsecurity-profiles-and-levels.md)** — what the Pod Security Standards are, what each of the three levels forbids, the `level` and `version` fields, and reading the multi-part violation message a PSS failure produces.
2. **[Part 2 — Excluding Controls, and PSS Versus PSA](./course-02-excluding-controls-and-psa.md)** — relaxing one control with `exclude` instead of dropping a level, scoping an exclusion to specific images or field values, and where Kyverno's `podSecurity` fits alongside Kubernetes' built-in Pod Security Admission.

## Learning objectives

After this module you can:

- Name the three Pod Security Standard levels and describe what moving between them changes.
- Write a `validate.podSecurity` rule with `level` and `version`, and explain what pinning a version protects you from.
- Read a PSS violation message and identify each individual control that failed.
- Exclude a specific control with `exclude`, scoped by `controlName` and optionally by `images` or by `restrictedField`/`values`.
- Explain why excluding one control is preferable to dropping from `restricted` to `baseline`.
- State how Kyverno's `podSecurity` rule differs from Kubernetes' built-in Pod Security Admission, and when each is the better tool.

## Before you start

You need Module 1 of this section — `match`, `validationFailureAction`, and the general shape of a rule. Modules 2 and 3 are not required.

Some familiarity with a Pod's `securityContext` helps, since that is where nearly every PSS control looks: `runAsNonRoot`, `allowPrivilegeEscalation`, `capabilities`, `seccompProfile`. The module explains each control it uses as it goes.

The **playground** linked at the top of this page gives you a `kind` cluster with Kyverno v1.19.1 running and **no policies installed**. Once it is up, `kubectl` is already pointed at it — the context is `kind-astro-ats-011-playground-0104` (Astrona prefixes the environment name with `astro-`). The `Try it` checkpoints in the parts below assume that environment is already running; they never repeat the startup command.
