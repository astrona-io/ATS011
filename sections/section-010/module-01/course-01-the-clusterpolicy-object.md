# Part 1: The ClusterPolicy Object and Its Audience

Every Kyverno policy is a Kubernetes resource, and every rule inside it begins by answering one question before it checks anything: *which resources am I even looking at?* This part settles the object and that question. Part 2 takes up what happens to the resources it selects.

## The resource that holds the rule

Every Kyverno policy is itself a Kubernetes resource. That single design choice is what makes Kyverno feel native: you `kubectl apply` a policy the same way you apply anything else, `kubectl get clusterpolicy` lists your rules, and RBAC governs who may change them.

There are two kinds:

- **`ClusterPolicy`** — cluster-scoped, its rules apply to matching resources in every namespace (unless narrowed).
- **`Policy`** — namespace-scoped, lives in one namespace and only governs resources in that namespace.

Both share the exact same `spec` shape. For this module we will use `ClusterPolicy`, since a validation rule for "every Pod needs a team label" is almost always something you want cluster-wide.

A minimal skeleton looks like this:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-team-label
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: check-team-label
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "A team label is required on every Pod."
        pattern:
          metadata:
            labels:
              team: "?*"
```

Four things are doing all the work here, and it's worth naming each one before going further:

| Field | Job |
| --- | --- |
| `spec.rules[].match` | Which resources this rule even looks at |
| `spec.validationFailureAction` | What happens when a matched resource fails the rule |
| `spec.rules[].validate.pattern` | The shape a matched resource must have |
| `spec.background` | Whether existing resources are scanned too, not just new admissions |

Save that skeleton as `policy.yaml` in the playground and apply it. Nothing is
being validated yet — a policy that has just been accepted by the API server is
not the same thing as a policy Kyverno has compiled and wired into its webhook,
and the `READY` column is where you see the difference.

> [!TIP]
> **Try it — a policy is just another resource**
>
> ```sh
> kubectl apply -f policy.yaml
> kubectl get clusterpolicy
> ```
>
> Expect something like:
>
> ```text
> clusterpolicy.kyverno.io/require-team-label created
> NAME                 ADMISSION   BACKGROUND   READY   AGE   MESSAGE
> require-team-label   true        true         True    6s    Ready
> ```
>
> `READY: True` is the signal the rule is live — `ADMISSION` and `BACKGROUND`
> echo back the two places it will run. You will also see a
> `kyverno.io/v1 ClusterPolicy is deprecated` warning on every apply; it is
> expected on this version and safe to ignore.

## match and exclude: choosing your audience

`match` is a filter, not a validator. A rule with no `match` block matches nothing — Kyverno never validates an accidental blank check. The `any` list under `match` is an OR: a resource matching **any** entry in the list is selected.

```yaml
match:
  any:
    - resources:
        kinds:
          - Pod
        namespaces:
          - "staging-*"
```

Common selectors inside a `resources` entry:

- `kinds` — one or more API kinds (`Pod`, `Deployment`, `Namespace`, …).
- `namespaces` — glob-matched namespace names.
- `selector` — a standard Kubernetes label selector, for matching resources that already carry a specific label.
- `names` — glob-matched resource names.

`exclude` uses the identical shape and is checked *after* `match`: a resource that matches `match` but also matches `exclude` is skipped. A common pattern is matching all Pods but excluding the `kube-system` namespace, so you don't fight the control plane's own workloads:

```yaml
match:
  any:
    - resources:
        kinds:
          - Pod
exclude:
  any:
    - resources:
        namespaces:
          - kube-system
```

## Section recap

A policy is an ordinary Kubernetes resource, which is what makes `kubectl apply`, `kubectl get`, and RBAC work on it unchanged. `ClusterPolicy` and `Policy` share a spec and differ only in reach. Inside a rule, `match` selects the audience and `exclude` carves out of that selection afterwards — and a rule with no `match` selects nothing at all rather than everything.
