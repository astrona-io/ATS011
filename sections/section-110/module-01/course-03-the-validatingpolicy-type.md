# Part 3: The ValidatingPolicy Type

Parts 1 and 2 used CEL as a guest inside the `ClusterPolicy` you already knew — one rule body swapped out, everything around it unchanged. This part introduces the policy family where CEL is not a guest but the only language, and where the surrounding shape changes too.

## The warning finally explained

Since Section 010, every `ClusterPolicy` you applied answered with:

```
Warning: kyverno.io/v1 ClusterPolicy is deprecated and will be removed in a future release
```

and in Section 100 the cleanup equivalent pointed at `DeletingPolicy`. Both are signposts to the same thing: a parallel family of policy types in the **`policies.kyverno.io`** API group, where CEL is not an option but the only expression language.

```bash
kubectl get crd -o name | grep policies.kyverno.io
# customresourcedefinition.apiextensions.k8s.io/validatingpolicies.policies.kyverno.io
# customresourcedefinition.apiextensions.k8s.io/mutatingpolicies.policies.kyverno.io
# customresourcedefinition.apiextensions.k8s.io/generatingpolicies.policies.kyverno.io
# customresourcedefinition.apiextensions.k8s.io/imagevalidatingpolicies.policies.kyverno.io
# customresourcedefinition.apiextensions.k8s.io/deletingpolicies.policies.kyverno.io
# ... plus a Namespaced* variant of each
```

One kind per job, rather than one `ClusterPolicy` kind holding rules of five different types. Each also has a `Namespaced*` counterpart, replacing the `ClusterPolicy`/`Policy` scoping pair.

`ValidatingPolicy` is the one this section covers, and the one whose shape you should recognise: it is deliberately modelled on Kubernetes' own `ValidatingAdmissionPolicy`, not on Kyverno's classic `ClusterPolicy`.

> [!NOTE]
> Deprecated does not mean gone, and it does not mean wrong to learn. `ClusterPolicy` is fully functional on v1.19.1, is what the KCA Writing Policies domain asks you to author, and is what you will meet in essentially every existing policy repository. Treat this part as "what the warning is pointing at and how to read one when you see it," not as a replacement for the previous ten sections.

## The shape, field by field

```yaml
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: require-team-label
spec:
  validationActions:
    - Deny
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  validations:
    - expression: "has(object.metadata.labels) && 'team' in object.metadata.labels && object.metadata.labels['team'] != ''"
      message: "Every Pod must carry a non-empty team label."
```

Read it against the `ClusterPolicy` you already know:

| `ValidatingPolicy` | `ClusterPolicy` equivalent | What changed |
| :--- | :--- | :--- |
| `spec.matchConstraints.resourceRules` | `rules[].match.any.resources` | API-group/version/resource triples and explicit `operations`, instead of bare `kinds`. |
| `spec.validations[].expression` | `rules[].validate.pattern` | CEL boolean, not a shape. |
| `spec.validationActions` | `spec.validationFailureAction` | A **list**, and the values are `Deny`/`Audit`/`Warn`, not `Enforce`/`Audit`. |
| (no `rules` array) | `spec.rules[]` | The policy is one rule's worth of policy. Multiple checks go in `validations`. |

Two of those differences cause most first-attempt failures. `resources: ["pods"]` is the lowercase plural **API resource name**, the same spelling RBAC uses — not the `Pod` kind you write in a `ClusterPolicy` `match`. And `operations` is required: omit `UPDATE` and your policy governs creation only, silently allowing an existing compliant Pod to be edited into a non-compliant one.

Apply it and it is ready in seconds — with no deprecation warning, because this is the current API:

```bash
kubectl apply -f vpol.yaml
# validatingpolicy.policies.kyverno.io/require-team-label created

kubectl get validatingpolicy
# NAME                 AGE   READY
# require-team-label   10s   true
```

## The rejection message is different

Apply it and submit the same pair of Pods you used against a `ClusterPolicy` in
Part 1. The outcomes will be identical; the wording will not be.

> [!TIP]
> **Try it — a different webhook, a different error shape**
>
> ```sh
> kubectl apply -f vpol.yaml
> kubectl get validatingpolicy
> kubectl run vp-bad --image=nginx --restart=Never
> kubectl run vp-good --image=nginx --restart=Never --labels=team=platform
> ```
>
> Expect something like:
>
> ```text
> validatingpolicy.policies.kyverno.io/require-team-label created
>
> NAME                 AGE   READY
> require-team-label   10s   true
>
> Error from server: admission webhook "vpol.validate.kyverno.svc-fail" denied the request: Policy require-team-label failed: Every Pod must carry a non-empty team label.
>
> pod/vp-good created
> ```
>
> Three differences worth naming: no deprecation warning on apply, the webhook is
> `vpol.validate.kyverno.svc-fail` rather than `validate.kyverno.svc-fail`, and
> the body is one line — `Policy <name> failed: <message>` — instead of the
> multi-line `resource ... was blocked due to the following policies` block. A
> separate webhook serves this policy family, and you can identify which family
> rejected a request from the error text alone.

## `matchConditions`: filtering before evaluating

`matchConstraints` selects on the coarse dimensions the API server indexes — group, version, resource, operation, and optionally namespace or object label selectors. `matchConditions` is a second, finer gate written in CEL, evaluated only on requests that already passed `matchConstraints`:

```yaml
spec:
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  matchConditions:
    - name: skip-kube-system
      expression: "object.metadata.namespace != 'kube-system'"
  variables:
    - name: containers
      expression: "object.spec.containers"
  validations:
    - expression: "variables.containers.all(c, has(c.resources) && has(c.resources.limits) && 'memory' in c.resources.limits)"
      message: "Every container must set a memory limit."
```

The distinction from `validations` is not cosmetic, and getting it backwards is a classic mistake:

* A **`matchCondition`** that evaluates to `false` means *this policy does not apply* — the request is skipped, silently and successfully.
* A **`validation`** that evaluates to `false` means *this request is non-compliant* — it is denied or audited according to `validationActions`.

So "Pods in `kube-system` are exempt" is a `matchCondition`. Writing it as part of a `validation` expression instead would still work, but it conflates "not my business" with "compliant," and the resulting expression is harder to read every time someone adds another check.

`matchConditions` are also a performance mechanism. Kyverno compiles a policy that carries them into its own fine-grained webhook, so the API server only calls out for requests that can possibly matter — visible in the rejection message, which names the specific webhook:

```bash
kubectl run vp-nolimit --image=nginx --restart=Never
# Error from server: admission webhook
# "vpol.validate.kyverno.svc-fail-finegrained-limits-required" denied the request:
# Policy limits-required failed: Every container must set a memory limit.
```

## `validationActions`: Deny, Audit, Warn

`validationActions` is a list, and the values do not match `ClusterPolicy`'s vocabulary:

| Value | Effect |
| :--- | :--- |
| `Deny` | The request is rejected. (The equivalent of `validationFailureAction: Enforce`.) |
| `Audit` | The request is admitted and the violation is recorded in a `PolicyReport`. |
| `Warn` | The request is admitted and a warning is returned to the client. |

Because it is a list you can combine them — `[Audit, Warn]` both records the violation and tells the person running `kubectl` about it, which is a good rollout posture before flipping to `Deny`. One combination is rejected: `Deny` and `Warn` together, on the grounds that it would report the same failure twice, once in the API response body and again in an HTTP warning header.

Under `Audit`, nothing blocks and a report appears:

```bash
kubectl run audit-pod --image=nginx --restart=Never
# pod/audit-pod created

kubectl get policyreport -n default
# NAMESPACE   NAME                                   KIND   NAME        PASS   FAIL   WARN   ERROR   SKIP   AGE
# default     b2fc2e36-ddad-4877-8911-fbbdf808fa40   Pod    audit-pod   0      1      0      0       0      1s
```

These are the same `PolicyReport` objects from Section 030, produced by the same reports controller. Background scanning applies here too — existing Pods that never passed through admission get evaluated and reported as well.

## Section recap

`ValidatingPolicy` is the CEL-native member of the `policies.kyverno.io` family that every deprecation warning in this course points at. `matchConstraints` replaces `match` and takes lowercase plural resource names with an explicit `operations` list; `validations` replaces `validate`; `validationActions` is a list drawn from `Deny`, `Audit`, and `Warn` rather than the `Enforce`/`Audit` pair. `matchConditions` is a separate gate answering "does this policy apply at all", distinct from a validation answering "is this request compliant" — and carrying them causes Kyverno to register a fine-grained webhook, visible in the rejection message itself.
