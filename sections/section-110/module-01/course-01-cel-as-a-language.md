# Part 1: CEL as a Language

## A pattern describes; an expression decides

Here is a requirement `validate.pattern` handles well — every Pod carries a non-empty `team` label:

```yaml
validate:
  message: "A team label is required on every Pod."
  pattern:
    metadata:
      labels:
        team: "?*"
```

You are drawing the resource and leaving a wildcard where the value goes. Kyverno walks the real resource against that drawing and reports where they diverge.

Now here is a requirement it handles badly: *every* container must set a memory limit. You can get close with a `foreach` block (Section 010), but the shape vocabulary has no way to say "all of them, and tell me if even one is missing" in a single readable assertion — and it has no way at all to express "the limit must be under 2Gi," or "`replicas` may only ever increase," or "at least two of these three labels must be present."

Those are not shapes. They are *questions with a yes-or-no answer*. That is precisely what CEL expresses:

```yaml
validate:
  cel:
    expressions:
      - expression: "object.spec.containers.all(c, has(c.resources) && has(c.resources.limits) && 'memory' in c.resources.limits)"
        message: "Every container must set spec.containers[].resources.limits.memory."
```

The mental shift is small but total. A `pattern` says **what the resource must look like**. A CEL `expression` says **what must be true about the resource** — it evaluates to a boolean, and `true` means admitted.

## What CEL is, and what it deliberately is not

CEL is not Kyverno's invention. It is the expression language Kubernetes itself adopted for CRD validation rules (`x-kubernetes-validations`) and for the built-in `ValidatingAdmissionPolicy` type. Learning it for Kyverno teaches you the same language you will meet everywhere else in the Kubernetes ecosystem.

Its defining property is what it *cannot* do. CEL has no loops you control, no recursion, no function definitions, no I/O, and is not Turing-complete. Every expression provably terminates, and the API server can estimate an expression's cost *before* running it and refuse one that is too expensive.

That is not a limitation the designers regretted — it is the entire point. Admission control sits in the synchronous path of every write to your cluster. A language in which someone can accidentally write an infinite loop is a language in which someone can accidentally stop the cluster accepting writes. CEL trades expressive power for a guarantee that it always finishes, quickly.

That guarantee is not a promise the language makes and hopes to keep — it is enforced structurally. Because there are no unbounded loops and no recursion, the *shape* of an expression determines an upper bound on its work before it runs. The API server exploits that: it walks the parsed expression, estimates a cost from the operations and the declared sizes of the fields involved, and refuses anything whose estimate exceeds a budget. An expression that would be expensive is rejected at policy-apply time rather than discovered at request time, which is the difference between a policy you cannot install and a cluster you cannot write to.

## The values Kyverno binds

Inside a `validate.cel` expression you have these in scope:

| Name | What it is |
| :--- | :--- |
| `object` | The resource being admitted. `null` on DELETE. |
| `oldObject` | The resource as it existed before this request. `null` on CREATE. |
| `request` | The `AdmissionRequest` — `request.operation`, `request.userInfo`, and so on. |
| `variables` | Your own named sub-expressions (below). |
| `namespaceObject` | The full `Namespace` object the resource is being created in. |

The `object`/`oldObject` pairing is what makes transition rules possible — comparing what something *was* to what it is *becoming*. `oldObject == null ? true : object.spec.replicas >= oldObject.spec.replicas` is a "replicas may never decrease" rule, and there is no way to write that as a shape at all, because a shape only ever sees one resource.

## The macros you will actually use

CEL has a compact standard library. Five entries cover the overwhelming majority of Kubernetes policies:

| Expression | Meaning |
| :--- | :--- |
| `has(object.spec.foo)` | The field is present. **Use this before touching optional fields.** |
| `list.all(x, <pred>)` | The predicate holds for every element. True for an empty list. |
| `list.exists(x, <pred>)` | The predicate holds for at least one element. |
| `list.exists_one(x, <pred>)` | The predicate holds for exactly one element. |
| `size(list)` / `size(string)` | Element or character count. |
| `'key' in someMap` | Map-key membership. |

Two subtleties worth internalising early. `all()` on an empty list is `true` — vacuously — so a rule that "every container must X" says nothing at all about a resource with no containers; if emptiness matters, assert `size()` separately. And `has()` tests *presence*, not truthiness: `has(object.metadata.labels)` is true for an empty labels map, so presence and non-emptiness are two different checks.

## Factoring with `variables`

When a sub-expression repeats — or is simply long — `variables` gives it a name. Each entry is a named CEL expression, and later expressions reference it as `variables.<name>`:

```yaml
validate:
  cel:
    variables:
      - name: containers
        expression: "object.spec.containers"
    expressions:
      - expression: "variables.containers.all(c, has(c.resources) && has(c.resources.limits) && 'memory' in c.resources.limits)"
        message: "Every container must set spec.containers[].resources.limits.memory."
```

Variables are evaluated lazily and may build on earlier ones, so a policy with several related checks can share one definition of "the containers I care about" rather than repeating a filter in every expression.

Variables are evaluated **before** any expression that references them, and in
the order they are written. That ordering is not a detail — Part 2 shows a
failure whose error names the *variable* rather than the predicate inside it,
precisely because the variable is evaluated first and never gets as far as the
predicate.

## Compiled against a schema, not against text

CEL is not string-substituted into place the way a `{{ }}` JMESPath variable is. It is parsed, type-checked against the schema of the kind your rule matches, and compiled — before any resource is submitted.

That has a directly useful consequence: Kyverno can tell you an expression is wrong at the moment you apply the policy, because it knows what a `Pod` looks like and can see that the field you named is not on it.

> [!TIP]
> **Try it — the compiler has already read your expression**
>
> ```sh
> kubectl apply -f unguarded-policy.yaml
> ```
>
> Expect something like:
>
> ```text
> Warning: spec.rules[0].validate.cel.expressions[0].expression:/v1, Kind=Pod: ERROR: <input>:1:42: undefined field 'limits'; | object.spec.containers.all(c, c.resources.limits['memory'] != ''); | .........................................^;
> clusterpolicy.kyverno.io/no-has-guard created
> ```
>
> Read the prefix: `/v1, Kind=Pod` — the expression was checked against the Pod
> schema specifically, which is how it knows `limits` is not guaranteed to be
> there. The caret points at the exact character offset. And note the last line:
> the policy was **created anyway**. This is a warning, not a refusal.

That last detail is the whole reason Part 2 exists. The compiler knows the expression is unsafe, tells you so, and installs it regardless — so the failure it predicted arrives later, at admission time, wearing a different disguise.

## Section recap

CEL states requirements as boolean questions rather than shapes, which is what makes cross-field comparison, arithmetic, and before-and-after rules expressible at all. It is deliberately not Turing-complete so that every expression terminates and its cost can be bounded before execution. Kyverno binds `object`, `oldObject`, `request`, `variables`, and `namespaceObject`; `has()`, `all()`, `exists()`, `exists_one()`, and `size()` cover nearly every Kubernetes policy. And because expressions are type-checked against the matched kind at apply time, Kyverno will warn you about a broken one before any resource is ever submitted — while still creating the policy.
