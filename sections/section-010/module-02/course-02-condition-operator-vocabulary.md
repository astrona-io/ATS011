# Part 2: The Condition Operator Vocabulary

## One syntax, many operators

Every condition entry has the same three fields, whatever it is testing:

```yaml
- key: "<the value being tested, usually a {{ }} variable>"
  operator: <one of the operators below>
  value: <what to test it against>
```

The operators fall into four families, and knowing which family you are in tells you what shapes `key` and `value` may take.

| Family | Operators | `key` / `value` shapes |
| :--- | :--- | :--- |
| Equality | `Equals`, `NotEquals` | single value to single value |
| Numeric | `GreaterThan`, `GreaterThanOrEquals`, `LessThan`, `LessThanOrEquals` | single values; numbers or Kubernetes quantities |
| Set | `AnyIn`, `AllIn`, `AnyNotIn`, `AllNotIn` | either side may be a single value or a list |
| Duration | `DurationGreaterThan`, `DurationGreaterThanOrEquals`, `DurationLessThan`, `DurationLessThanOrEquals` | Go duration strings (`30s`, `15m`, `2h`) or seconds |

Operator names are **case-sensitive exactly as written**. `equals` is not `Equals`, and a mistyped operator is a policy-level error rather than a silently-false condition.

Two details that save time later. The numeric operators understand Kubernetes' own quantity suffixes, so `key: "{{ request.object.spec.containers[0].resources.limits.memory }}"` against `value: 2Gi` compares as memory rather than as a string — and comparing `512Mi` against `1Gi` gets the scales right. And string comparisons support `*` as a wildcard, so `Equals` with `value: "ghcr.io/*"` is a prefix test rather than an exact one.

## Why there are four set operators

`In`-style operators exist in a two-by-two grid, and the names are more readable once you see the axes: **Any versus All**, and **In versus NotIn**.

| Operator | True when |
| :--- | :--- |
| `AnyIn` | at least one key is found among the values |
| `AllIn` | every key is found among the values |
| `AnyNotIn` | at least one key is *not* found among the values |
| `AllNotIn` | no key at all is found among the values |

The Any/All axis only matters when `key` resolves to a **list**. Against a single value, `AnyIn` and `AllIn` mean the same thing — which is why plenty of working policies use them interchangeably and their authors never notice the distinction until a key starts resolving to more than one item.

The classic use is a controlled vocabulary: a label whose value must be drawn from a fixed set. Written as a deny rule, that inverts to "reject when the value is *not* in the set":

```yaml
validate:
  message: >-
    tier must be one of frontend/backend/batch;
    got '{{ request.object.metadata.labels.tier || '' }}'.
  deny:
    conditions:
      all:
        - key: "{{ request.object.metadata.labels.tier || '' }}"
          operator: AnyNotIn
          value: ["frontend", "backend", "batch"]
```

The `|| ''` fallback matters here for the same reason it did in Section 020 and Section 080: a Pod with no `tier` label at all would otherwise leave the variable unresolved, and an unresolved variable is an evaluation error rather than a value that fails the test. With the fallback, a missing label resolves to `''`, which is legitimately not in the list — so "absent" is treated as "invalid", which is almost always what a vocabulary rule wants.

> [!TIP]
> **Try it — a controlled vocabulary, including the empty case**
>
> ```sh
> kubectl apply -f label-vocabulary.yaml
> kubectl run v-ok   --image=nginx --restart=Never --labels=tier=frontend
> kubectl run v-bad  --image=nginx --restart=Never --labels=tier=weird
> kubectl run v-none --image=nginx --restart=Never
> ```
>
> Expect something like:
>
> ```text
> pod/v-ok created
>
> label-vocabulary:
>   tier-must-be-known: tier must be one of frontend/backend/batch; got 'weird'.
>
> label-vocabulary:
>   tier-must-be-known: tier must be one of frontend/backend/batch; got ''.
> ```
>
> Three Pods, three distinct outcomes worth separating: a permitted value, a
> present-but-invalid value, and no value at all. The third is the one the `|| ''`
> fallback is protecting — without it that request produces a variable-resolution
> error instead of this message.

## Denying per list element with `foreach`

A condition tests one value. When the thing you need to test is *every container's image*, a single condition cannot express it — the same limitation Module 1 met with `pattern` against a list, and the same fix: `foreach` runs the rule body once per element, with the current element bound to `element`.

`foreach` accepts a `deny` just as it accepts a `pattern`:

```yaml
validate:
  message: >-
    Every image must come from an approved registry.
    Found: {{ request.object.spec.containers[*].image }}
  foreach:
    - list: "request.object.spec.containers"
      deny:
        conditions:
          all:
            - key: "{{ regex_match('^(ghcr.io/|registry.k8s.io/).*', '{{ element.image }}') }}"
              operator: Equals
              value: false
```

Two things are happening in that `key`. `regex_match` is a JMESPath function Kyverno provides — it returns a boolean, and comparing that boolean against `false` is how you express "this image did **not** match an approved prefix". The nested `{{ element.image }}` is the current container's image, substituted before the outer expression is evaluated.

The polarity is worth tracing once more, because two negations stack here: the regex describes what is *allowed*, `Equals false` turns it into *not allowed*, and `deny` turns *not allowed* into a rejection. Reading it inside out — "match an approved prefix" → "did not match" → "deny that" — keeps it straight.

> [!TIP]
> **Try it — one rejected registry, one accepted**
>
> ```sh
> kubectl apply -f registry-allowlist.yaml
> kubectl run dh --image=nginx --restart=Never
> kubectl run ok --image=registry.k8s.io/pause:3.9 --restart=Never
> ```
>
> Expect something like:
>
> ```text
> registry-allowlist:
>   only-approved-registries: 'validation failure: Every image must come from an approved registry. Found: ["nginx"]'
>
> pod/ok created
> ```
>
> A bare `nginx` is a Docker Hub reference once Kubernetes resolves it, so it
> fails the prefix test. Note the message quotes the whole image list — that is
> `containers[*].image` resolving against the request, not the single failing
> element, which is why a multi-container Pod's message names every image rather
> than just the offender.

That last detail is a real limitation to know: inside a `foreach`, the *rule-level* `message` is still evaluated against the whole resource. If you want to name only the offending element, reference `{{ element.image }}` in the message instead of `containers[*].image`.

> [!WARNING]
> **Common pitfalls**
>
> - **Mistyping an operator's case.** `anyIn` or `ANYIN` are not the operator; this fails at the policy level rather than evaluating to false.
> - **Assuming `AnyIn` and `AllIn` are interchangeable.** They are, right up until `key` resolves to a list — at which point the rule quietly changes meaning.
> - **Omitting `|| ''` on an optional field.** An unresolved variable is an evaluation error, not a false condition.
> - **Comparing quantities as strings.** Use the numeric operators, which understand `Mi`/`Gi`/`m`; `Equals` against `"512Mi"` is a string match and will miss `0.5Gi`.
> - **Expecting the rule message to name the failing element inside a `foreach`.** It resolves against the whole resource unless you reference `element` explicitly.

## Section recap

Conditions share one `key`/`operator`/`value` syntax across four operator families — equality, numeric, set, and duration — with case-sensitive names. The four set operators are a two-by-two grid of Any/All against In/NotIn, and the Any/All axis only bites once `key` resolves to a list. `foreach` combined with `deny` tests every element of a list independently, and the `|| ''` fallback is what keeps an optional field from turning a condition into an evaluation error.
