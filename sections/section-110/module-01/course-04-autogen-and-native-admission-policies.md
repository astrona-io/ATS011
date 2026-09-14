# Part 4: Autogen and Native Admission Policies

Part 3 left one question open. If a `ValidatingPolicy` is written in the API server's own expression language, does Kyverno need to be in the request path at all?

It does not — and this part is about the machinery that lets it step out, plus the Section 090 behaviour that carries over unchanged into the new policy family.

## Autogen carries over

Section 090's autogen is not a `ClusterPolicy` feature; it is a Kyverno feature, and it applies to CEL policies too. Submit a Deployment whose Pod template lacks the label, against a `ValidatingPolicy` that only ever mentioned `pods`:

```bash
kubectl create deployment vp-deploy --image=nginx
# error: failed to create deployment: admission webhook "vpol.validate.kyverno.svc-fail"
# denied the request: Policy require-team-label failed: Every Pod must carry a non-empty team label.
```

The generated variants live on the policy's status, under a slightly different path than Section 090's `status.autogen.rules`:

> [!TIP]
> **Try it — autogen, rewritten inside a CEL string**
>
> ```sh
> kubectl create deployment vp-deploy --image=nginx
> kubectl get validatingpolicy require-team-label -o jsonpath='{.status.autogen}'
> ```
>
> Expect the Deployment to be rejected by `vpol.validate.kyverno.svc-fail`, and
> the status to contain two generated configs — `defaults` and `cronjobs` — whose
> expressions read `object.spec.template.metadata.labels` and
> `object.spec.jobTemplate.spec.template.metadata.labels` respectively. The
> rewriting happened inside the expression string, not in a YAML pattern.

```json
{"configs":{
  "defaults":{"spec":{
    "matchConstraints":{"resourceRules":[
      {"apiGroups":["apps"],"apiVersions":["v1"],"operations":["CREATE","UPDATE"],
       "resources":["daemonsets","deployments","replicasets","statefulsets"]},
      {"apiGroups":["batch"],"apiVersions":["v1"],"operations":["CREATE","UPDATE"],
       "resources":["jobs"]}]},
    "validations":[{"expression":"has(object.spec.template.metadata.labels) && 'team' in object.spec.template.metadata.labels && object.spec.template.metadata.labels['team'] != ''"}]}},
  "cronjobs":{"spec":{
    "matchConstraints":{"resourceRules":[
      {"apiGroups":["batch"],"apiVersions":["v1"],"operations":["CREATE","UPDATE"],
       "resources":["cronjobs"]}]},
    "validations":[{"expression":"has(object.spec.jobTemplate.spec.template.metadata.labels) && ..."}]}}}}
```

Exactly the Section 090 story in a new syntax. The same two groupings — the six kinds sharing `spec.template`, and CronJob alone with its deeper `spec.jobTemplate.spec.template` — and the same mechanical path rewriting, except that here it rewrites *inside a CEL expression string* rather than inside a YAML pattern. `object.metadata.labels` becomes `object.spec.template.metadata.labels`, automatically, in every generated expression.

## Generating a real Kubernetes ValidatingAdmissionPolicy

This is the part with genuinely different architecture behind it.

Kubernetes has its own built-in CEL policy type — `ValidatingAdmissionPolicy` (VAP) — enforced by the API server directly, with no webhook and no external process involved. Because a Kyverno CEL policy is already written in the API server's own language, Kyverno can compile one into a real VAP and hand enforcement over:

```yaml
spec:
  autogen:
    validatingAdmissionPolicy:
      enabled: true
```

> [!TIP]
> **Try it — Kyverno writing a native Kubernetes policy object**
>
> ```sh
> kubectl apply -f vpol-with-vap.yaml
> kubectl get validatingadmissionpolicy
> kubectl get validatingadmissionpolicybinding
> kubectl run vap-bad --image=nginx --restart=Never
> ```
>
> Expect something like:
>
> ```text
> NAME                  VALIDATIONS   PARAMKIND   AGE
> vpol-vap-team-label   1             <unset>     15s
>
> NAME                          POLICYNAME            PARAMREF   AGE
> vpol-vap-team-label-binding   vpol-vap-team-label   <unset>    15s
>
> The pods "vap-bad" is invalid: : ValidatingAdmissionPolicy 'vpol-vap-team-label' with binding 'vpol-vap-team-label-binding' denied request: Every Pod must carry a team label.
> ```
>
> Read the last line for what is *missing*: there is no `admission webhook ...
> denied the request` anywhere in it. The API server enforced its own policy
> object. Kyverno wrote the VAP and the binding, then stepped out of the request
> path — and a VAP cannot fail because a webhook is unreachable, because there is
> no webhook to reach.

Kyverno created both objects — a VAP holding the translated expression and a binding that activates it. The generated names are prefixed by source kind: `vpol-` for a `ValidatingPolicy`. The same switch exists on the classic side as `validate.cel.generate: true` inside a `ClusterPolicy` rule, which produces a `cpol-`-prefixed VAP instead.

That has a real operational consequence. Webhook-based admission control fails when the webhook is unreachable — Kyverno pods restarting, a network partition, a node under pressure — and how it fails depends on `failurePolicy`. A VAP has no such failure mode, because there is nothing to reach. For a small, stable, security-critical rule, generating a VAP removes an entire class of outage.

The trade is expressiveness. A VAP can only do what the API server's CEL environment supports: no `context.apiCall` to fetch live cluster data (Section 070), no image-registry lookups (Section 060), no generation or mutation. Only the subset of your policy that translates gets translated — which is why this is a per-policy switch rather than a cluster-wide mode.

The pipeline is worth stating as a sequence, because three different objects are involved and only one of them is yours:

```text
  your ValidatingPolicy            (policies.kyverno.io)
        |
        |  Kyverno's admission-policy generator compiles it
        v
  ValidatingAdmissionPolicy        (admissionregistration.k8s.io)   name: vpol-<your-name>
        +
  ValidatingAdmissionPolicyBinding (admissionregistration.k8s.io)   name: vpol-<your-name>-binding
        |
        |  the API server enforces these directly
        v
  admission decision, with no webhook call
```

Both generated objects matter. The `ValidatingAdmissionPolicy` holds the translated expressions; the binding is what activates it against resources. A policy with no binding enforces nothing at all, which is why the checkpoint above reads both.

The `vpol-` prefix names the source kind. The same switch exists on the classic side as `validate.cel.generate: true` inside a `ClusterPolicy` rule, and produces a `cpol-`-prefixed pair instead — so a glance at a generated policy's name tells you which kind of Kyverno policy compiled it.

### Three ways a Pod gets rejected

By the end of this section you have seen three distinct rejection messages, and telling them apart is a fast diagnostic:

| Message starts with | Enforced by |
| :--- | :--- |
| `admission webhook "validate.kyverno.svc-fail" denied the request:` followed by `resource ... was blocked due to the following policies` | A classic `ClusterPolicy`, via Kyverno's webhook |
| `admission webhook "vpol.validate.kyverno.svc-fail..." denied the request: Policy <name> failed:` | A `ValidatingPolicy`, via Kyverno's CEL webhook |
| `The pods "<name>" is invalid: : ValidatingAdmissionPolicy '<name>' with binding '<name>' denied request:` | The API server, via a generated VAP — Kyverno not involved at request time |

## Common pitfalls

> [!WARNING]
> **Writing `resources: ["Pod"]` in `matchConstraints`.** It takes the lowercase plural API resource name — `pods` — the same spelling RBAC uses, not the `Kind`.
>
> **Omitting `UPDATE` from `operations`.** The policy then governs creation only, and an existing compliant resource can be edited into a non-compliant one without objection.
>
> **Using `Enforce` in `validationActions`.** That is `ClusterPolicy` vocabulary. The values here are `Deny`, `Audit`, and `Warn`.
>
> **Putting an exemption in `validations` instead of `matchConditions`.** Both produce the right outcome, but they mean different things — "does not apply" versus "is compliant" — and the confusion compounds with every check you add.
>
> **Expecting a generated VAP to do everything the policy did.** Only what the API server's CEL environment supports translates. Anything needing live cluster lookups or registry access stays with Kyverno.

## Section recap

Autogen is a Kyverno feature rather than a `ClusterPolicy` feature, so a `ValidatingPolicy` matching only `pods` still governs Pod controllers — with the path rewriting performed inside the CEL expression strings and reported under `status.autogen.configs`. Enabling `autogen.validatingAdmissionPolicy` makes Kyverno compile the policy into a native `ValidatingAdmissionPolicy` plus a binding, moving enforcement into the API server and out of any webhook — at the cost of everything CEL alone cannot reach: live cluster lookups, registry access, mutation, and generation.
