# Part 1: Generating from Literal Data

## A rule type that creates, instead of gatekeeps

Every rule type you've met so far in this course shares one property: something else initiates the request, and Kyverno decides what happens to *that* request. A Pod shows up; `validate` accepts or rejects it. A Pod already exists; a background scan reports on it. Nothing so far has ever caused a *new* resource to spring into existence on its own.

`generate` breaks that pattern. A `generate` rule watches for a **trigger** resource — most commonly a `Namespace` being created — and, when it fires, creates one or more entirely separate **downstream** resources. Nobody writes the downstream resource by hand, and nobody applies it. It exists purely because the trigger existed and a policy said it should.

The classic use case is the one this module builds: a platform team wants every namespace on the cluster, from now on, to automatically receive a default-deny `NetworkPolicy`, without trusting every application team to remember to write one themselves.

## The shape of a generate rule

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: generate-default-deny-netpol
spec:
  rules:
    - name: default-deny-ingress
      match:
        any:
          - resources:
              kinds:
                - Namespace
      exclude:
        any:
          - resources:
              namespaces:
                - kube-system
                - kube-public
                - kube-node-lease
                - kyverno
      generate:
        apiVersion: networking.k8s.io/v1
        kind: NetworkPolicy
        name: default-deny-ingress
        namespace: "{{request.object.metadata.name}}"
        data:
          spec:
            podSelector: {}
            policyTypes:
              - Ingress
```

Read this top to bottom the same way you read a validate rule: `match` decides which resources are the **trigger**. Everything under `generate` decides what gets **created** in response. The fields worth naming individually:

| Field | Job |
| --- | --- |
| `generate.apiVersion` / `kind` | The API type of the resource to create |
| `generate.name` | The name the new resource gets |
| `generate.namespace` | Which namespace the new resource lands in (omitted for cluster-scoped generated resources) |
| `generate.data` | A literal manifest — whatever you write here becomes the generated resource's body |

## match on kind: Namespace — the classic trigger

`Namespace` is by far the most common `generate` trigger, for a simple reason: a namespace is the natural boundary at which a platform team wants to guarantee some baseline exists, and namespace creation is a relatively rare, deliberate event compared to, say, Pod creation. But the trigger doesn't have to be a Namespace — `match` here works exactly like it does for `validate`, so any resource kind Kyverno can watch can drive a `generate` rule. This module and its lab use `Namespace` throughout because it's the shape the KCA exam expects you to recognize immediately.

Notice `generate.namespace` is set to `"{{request.object.metadata.name}}"` — this is the same `{{ }}` variable syntax from Section 010's messages, and `request.object` here refers to the trigger resource itself: the Namespace that was just created. Its `metadata.name` *is* the name of the namespace, so this line reads as "put the generated resource inside whichever namespace triggered this rule." Without this, you'd need one hardcoded namespace per rule, which defeats the entire purpose of a rule that's supposed to cover every namespace that will ever exist.

## generate.data: writing the manifest directly into the policy

`data` is the simpler of `generate`'s two source mechanisms (Part 2 covers the other, `clone`). Whatever structure you write under `data` becomes the generated resource's body, field for field — exactly the same mental model as `validate.pattern`, except here Kyverno isn't comparing your YAML against an incoming resource, it's *manifesting* your YAML as a brand-new one.

```yaml
data:
  spec:
    podSelector: {}
    policyTypes:
      - Ingress
```

This produces a `NetworkPolicy` whose `spec.podSelector` is the empty selector (meaning: applies to every Pod in the namespace, since an empty selector matches everything) and whose `spec.policyTypes` is `[Ingress]` — a policy that, by omitting any `ingress:` rules while declaring `Ingress` as a governed policy type, denies all inbound traffic to every Pod in the namespace by default. `data` supports the same `{{ }}` variable interpolation as everywhere else in a policy, so a more elaborate rule could, for instance, template a label with the triggering namespace's own name into the generated resource.

Apply that policy in the playground and then create a namespace. The point is
that you will write no `NetworkPolicy` manifest at any stage, and one will exist
anyway.

> [!TIP]
> **Try it — a namespace produces a resource nobody wrote**
>
> ```sh
> kubectl apply -f generate-policy.yaml
> kubectl create ns team-checkout
> kubectl get netpol -n team-checkout
> ```
>
> Expect something like:
>
> ```text
> clusterpolicy.kyverno.io/generate-default-deny-netpol created
> namespace/team-checkout created
>
> NAME                   POD-SELECTOR   AGE
> default-deny-ingress   <none>         3s
> ```
>
> If the last command says `No resources found`, wait a few seconds and repeat —
> generation is asynchronous, driven by Kyverno's background controller after
> the Namespace is admitted, not by the admission response itself.

That asynchrony is worth holding onto. Unlike `validate` and `mutate`, which
finish inside the admission request, a `generate` rule's work happens *after*
`kubectl create ns` has already returned success. A script that creates a
namespace and immediately expects the generated resource to be there will
intermittently fail, and the fix is to wait for the resource rather than to
assume the namespace's creation implies it.

Look at what landed, and note that `{{request.object.metadata.name}}` in the
policy resolved to the namespace that triggered the rule:

```bash
kubectl get netpol default-deny-ingress -n team-checkout -o yaml
# spec:
#   podSelector: {}
#   policyTypes:
#   - Ingress
```

The `spec` is verbatim what you wrote under `generate.data`. That is the whole
contract of the `data` form: the policy carries the downstream manifest inside
itself.
