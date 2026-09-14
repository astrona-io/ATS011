# Part 1: Profiles, Levels, and Versions

## What the Pod Security Standards are

The Pod Security Standards (PSS) are a Kubernetes specification, not a Kyverno feature. They define three cumulative profiles, each a named set of controls on a Pod's security-relevant fields:

| Level | What it means |
| :--- | :--- |
| `privileged` | Unrestricted. Everything is allowed; the profile exists so "no restriction" has a name. |
| `baseline` | Blocks known privilege-escalation paths: privileged containers, host namespaces, host ports, most `hostPath` volumes, adding dangerous capabilities. Ordinary applications generally pass without changes. |
| `restricted` | Baseline plus hardening that applications must opt into: run as non-root, drop all capabilities, disallow privilege escalation, set a seccomp profile. Most off-the-shelf images fail this until their manifests are adjusted. |

They are cumulative: everything `baseline` forbids, `restricted` also forbids. The jump that matters is `baseline` → `restricted`, because that is where a profile stops describing "not obviously dangerous" and starts requiring positive declarations in every Pod spec.

## The rule body

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: pss-baseline
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: baseline-standard
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "This Pod violates the Pod Security Standards baseline profile."
        podSecurity:
          level: baseline
          version: latest
```

`podSecurity` sits where `pattern` or `deny` would — it is a rule body, so the usual one-body-per-rule constraint applies. Everything outside `validate` is the ordinary policy you already know.

Try it against the clearest possible violation: a privileged container.

> [!TIP]
> **Try it — a whole profile in two lines**
>
> ```sh
> kubectl apply -f pss-baseline.yaml
>
> kubectl apply -f - <<'EOF'
> apiVersion: v1
> kind: Pod
> metadata: {name: pss-bad}
> spec:
>   containers:
>     - name: app
>       image: nginx:1.27
>       securityContext: {privileged: true}
> EOF
>
> kubectl run pss-ok --image=nginx:1.27 --restart=Never
> ```
>
> Expect something like:
>
> ```text
> pss-baseline:
>   baseline-standard: 'Validation rule ''baseline-standard'' failed. It violates PodSecurity "baseline:latest": (Forbidden reason: privileged, field error list: [spec.containers[0].securityContext.privileged is forbidden, forbidden values found: true])'
>
> pod/pss-ok created
> ```
>
> A plain `nginx` Pod with no `securityContext` at all passes `baseline` — that is
> the profile's design intent. Only the privileged container is rejected, and the
> message names the control (`privileged`), the exact field, and the offending
> value.

## Reading a PSS violation

A PSS failure message is structured differently from every other validation error in this course, and it repays a careful read. There is no single `failed at path`; instead there is one parenthesised block per violated control:

```text
(Forbidden reason: <control>, field error list: [<field>: <what was wrong>])
```

A Pod that violates several controls produces several blocks in one message. The `restricted` profile applied to an ordinary image is the clearest demonstration:

```text
It violates PodSecurity "restricted:latest":
(Forbidden reason: seccompProfile, field error list: [spec.containers[0].securityContext.seccompProfile.type: Required value])
(Forbidden reason: allowPrivilegeEscalation != false, field error list: [spec.containers[0].securityContext.allowPrivilegeEscalation: Required value])
(Forbidden reason: runAsNonRoot != true, field error list: [spec.containers[0].securityContext.runAsNonRoot: Required value])
```

Three separate controls, three separate fixes, all reported at once. Note the wording `Required value` — under `restricted`, these fields are not merely constrained when present; they must be explicitly set. That is exactly the difference between the two profiles: `baseline` mostly forbids things, `restricted` also *requires* things.

The corresponding compliant Pod makes the shape of the fix obvious:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: r-ok
spec:
  securityContext:
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: app
      image: nginx:1.27
      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop: ["ALL"]
```

Note that some controls are satisfied at Pod level (`runAsNonRoot`, `seccompProfile`) and some at container level (`allowPrivilegeEscalation`, `capabilities`). A Pod-level setting applies to every container unless a container overrides it, which is why hardening is usually written once at Pod level and only specialised where genuinely needed.

## Pinning the version

`version` selects which revision of the standard to enforce:

```yaml
podSecurity:
  level: restricted
  version: v1.31
```

The accepted values run from `v1.19` through the releases your Kyverno build knows about, plus `latest`. `latest` is the default if you omit the field.

`latest` is convenient and is a genuine risk in a policy you intend to leave alone. The Pod Security Standards are revised between Kubernetes releases — controls get added, and a profile that your workloads passed last quarter can start rejecting them after a Kyverno upgrade, with no change to your policy or your manifests. On an `Enforce` policy that surfaces as deployments failing for a reason nobody changed.

Pinning a version makes profile changes an explicit decision: workloads keep passing until someone bumps the number, reads what changed, and fixes what needs fixing. The trade is that a pinned policy does not pick up new protections automatically. For a policy in `Audit`, `latest` is fine and arguably better — you want to see new violations. For `Enforce`, pin it.

> [!WARNING]
> **Common pitfalls**
>
> - **Expecting `baseline` to harden anything.** It blocks dangerous configurations; it does not require secure ones. A Pod running as root with no seccomp profile passes `baseline` comfortably.
> - **Jumping straight to `restricted` in `Enforce`.** Most existing workloads fail it. Run it in `Audit` first and read the reports; Section 000 covers using `validationFailureActionOverrides` to enforce it in one namespace at a time.
> - **Reading only the first violation in the message.** A PSS failure lists every failed control; fixing the first one and resubmitting will just surface the next.
> - **Leaving `version: latest` on an enforcing policy.** A Kyverno upgrade can then change what your policy rejects without anyone editing it.

## Section recap

The Pod Security Standards are three cumulative upstream profiles, and `validate.podSecurity` enforces one by name rather than making you reproduce it. `baseline` forbids dangerous configurations; `restricted` additionally requires explicit hardening fields, which is why ordinary images fail it. A PSS violation message carries one block per failed control rather than a single field path, and `version` should be pinned on any policy that enforces rather than audits.
