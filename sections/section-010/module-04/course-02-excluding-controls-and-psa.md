# Part 2: Excluding Controls, and PSS Versus PSA

## The problem with dropping a level

One workload needs a capability that `restricted` forbids. The tempting fix is to move that namespace's policy from `restricted` to `baseline`.

That trades one exemption for dozens. `restricted` is not a single control — it is roughly a dozen of them, and dropping to `baseline` abandons the seccomp requirement, the non-root requirement, the privilege-escalation requirement, and the capability drop, when the actual need was one of those.

`podSecurity.exclude` relaxes a **named control** while leaving the rest of the profile intact:

```yaml
validate:
  message: "This Pod violates the Pod Security Standards restricted profile."
  podSecurity:
    level: restricted
    version: latest
    exclude:
      - controlName: "Capabilities"
        images: ["nginx*"]
```

`controlName` takes a value from the Pod Security Standards' own control list — `HostProcess`, `Host Namespaces`, `Privileged Containers`, `Capabilities`, `Seccomp`, `Running as Non-root`, and the rest. The names are fixed by the upstream specification and the field is schema-validated, so a typo is rejected when you apply the policy rather than silently ignored.

`images` narrows the exclusion to containers running matching images, with `*` and `?` wildcards. Omit it and the exclusion applies to the whole Pod; supply it and only the matching containers get the relaxation, while every other container in the same Pod is still held to the full profile.

> [!TIP]
> **Try it — one control relaxed, the rest still enforced**
>
> ```sh
> kubectl apply -f pss-restricted-with-exclusion.yaml
> kubectl run r-bad --image=nginx:1.27 --restart=Never
> ```
>
> Expect something like:
>
> ```text
> pss-restricted-with-exclusion:
>   restricted-except-one-control: 'Validation rule ''restricted-except-one-control'' failed. It violates PodSecurity "restricted:latest": (Forbidden reason: seccompProfile, field error list: [spec.containers[0].securityContext.seccompProfile.type: Required value])(Forbidden reason: allowPrivilegeEscalation != false, field error list: [spec.containers[0].securityContext.allowPrivilegeEscalation: Required value])(Forbidden reason: runAsNonRoot != true, field error list: [spec.containers[0].securityContext.runAsNonRoot: Required value])'
> ```
>
> Three controls failed — and read which one is *absent* from that list. There is
> no capabilities violation, even though a plain `nginx` container drops nothing.
> That control was excluded for `nginx*` images; everything else in `restricted`
> still applies.

That absence is the whole mechanism, and it is worth noting that it is visible only by comparison. Applying the same profile without the `exclude` block produces a fourth block about capabilities. If you want to be certain an exclusion is doing what you think, remove it and diff the messages.

## Narrowing an exclusion to specific values

`images` scopes an exclusion by *which container*. Two further fields scope it by *what the container is asking for*:

```yaml
exclude:
  - controlName: "Capabilities"
    restrictedField: "spec.containers[*].securityContext.capabilities.add"
    values: ["NET_BIND_SERVICE"]
```

`restrictedField` names the exact field the control governs, and `values` lists the values permitted in it. Read together: *relax the Capabilities control, but only for the `add` list, and only for `NET_BIND_SERVICE`.* A container adding `SYS_ADMIN` is still rejected by the same rule.

This is the form to reach for when the exemption is about a specific, reviewed requirement rather than a blanket "this image is special". `NET_BIND_SERVICE` — needed to bind a port below 1024 — is the textbook case: a legitimate need, granted precisely, with every other capability still forbidden.

Omitting `restrictedField` selects all restricted fields for that control, which is the broad form used in the first example.

> [!NOTE]
> An exclusion is a documented, reviewable object in the policy. That is its real advantage over the alternatives: the profile still says `restricted`, and the exception sits next to it naming the control, the scope, and — if you write `restrictedField`/`values` — the exact privilege granted. Compare that with a namespace quietly moved to `baseline`, where the reason is recorded nowhere and the scope is everything.

## Kyverno's podSecurity versus Kubernetes' Pod Security Admission

Kubernetes has its own built-in enforcement of the same standards: **Pod Security Admission** (PSA), configured by labelling a namespace.

```bash
kubectl label ns team-prod pod-security.kubernetes.io/enforce=restricted
```

Same profiles, same controls, no Kyverno involved. So why does the Kyverno rule exist?

| | Pod Security Admission | Kyverno `podSecurity` |
| :--- | :--- | :--- |
| Configured by | a namespace label | a policy object |
| Granularity | whole namespace, one level | any `match`/`exclude` selector Kyverno supports |
| Exempting a control | not possible — only whole-namespace exemption | `exclude` by control, image, field, and value |
| Reporting | warnings and audit annotations | `PolicyReport` objects, alongside every other policy |
| Who can change it | anyone who can edit the namespace | anyone who can edit the policy |

The deciding differences are the middle two rows. PSA is all-or-nothing per namespace: one workload needing one capability forces the entire namespace down a level. And PSA's exemptions are configured in the API server's admission configuration file — a cluster-level change, not something a policy author can express.

The practical arrangement many clusters land on is both: PSA as a floor that cannot be bypassed by editing a policy, and Kyverno on top for the granular rules, the reporting, and the exclusions. They do not conflict; a Pod has to satisfy whichever admission checks apply to it.

> [!WARNING]
> **Common pitfalls**
>
> - **Dropping a level to solve one control.** Use `exclude`; the level is not the unit of exemption.
> - **Guessing at `controlName`.** The names come from the upstream Pod Security Standards and the field is schema-validated — check the spelling rather than inventing it.
> - **Writing a blanket exclusion where a scoped one would do.** `images` and `restrictedField`/`values` exist so an exemption can be as narrow as the need.
> - **Assuming Kyverno's rule replaces PSA.** They are independent admission paths; a namespace labelled for PSA still enforces PSA regardless of what your policy says.
> - **Expecting an exclusion to show up in the failure message.** It shows up as an *absence*. Compare against the same policy without the exclusion if you need to confirm it.

## Section recap

`exclude` relaxes a named control instead of abandoning a profile, scoped by `controlName` and optionally narrowed by `images` or by `restrictedField` plus `values`. That keeps the exemption documented, reviewable, and as small as the requirement. Kubernetes' own Pod Security Admission enforces the same standards at namespace granularity with no per-control exemptions, which is why the two are commonly run together rather than as alternatives.
