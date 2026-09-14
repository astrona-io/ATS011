# Part 1: The Preconditions Block and Its Operators

## A second gate, after match already let the resource in

Section 010 drew a firm line: `match`/`exclude` decides *which resources a rule even looks at*, and `validate.pattern` decides *whether the resource passes*. That two-step model works right up until the rule you need to express is "check this, except when…" and the exception isn't something `match`'s vocabulary of kind/namespace/label/name can state.

`preconditions` is Kyverno's answer. It sits between `match` and the rule body (`validate`, `mutate`, or `generate`), and it asks a yes/no question about the *specific resource that already matched* — not about resources in general. If the answer is no, the rule body never runs at all for that resource, exactly as if `match` had excluded it. If the answer is yes, execution proceeds to `validate`/`mutate`/`generate` as normal.

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-team-label-with-exemption
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: check-team-label-unless-exempt
      match:
        any:
          - resources:
              kinds:
                - Pod
      preconditions:
        all:
          - key: "{{ request.object.metadata.labels.tier || '' }}"
            operator: NotEquals
            value: "exempt"
      validate:
        message: "A team label is required on every Pod, unless it carries tier: exempt."
        pattern:
          metadata:
            labels:
              team: "?*"
```

Read this rule top to bottom the way Kyverno evaluates it: `match` says "every Pod." `preconditions` says "but only actually check the ones that aren't labeled `tier: exempt`." `validate` says "and here's what 'check' means: a non-empty `team` label." Three independent decisions, three independent blocks — that separation of concerns is the entire reason `preconditions` exists as its own field instead of being folded into the pattern itself.

## The shape: any and all, exactly like match

`preconditions` supports the same two list keys you already know from `match`/`exclude`:

- **`preconditions.all`** — every condition in the list must be true. Logical AND.
- **`preconditions.any`** — at least one condition in the list must be true. Logical OR.

You can nest them (an `all` block containing an `any` block, or vice versa) for compound logic, but most real policies need only one level. Each individual condition is a three-field object:

```yaml
preconditions:
  all:
    - key: <expression>
      operator: <OperatorName>
      value: <comparison value>
```

- **`key`** — the left-hand side. Almost always a `{{ }}` variable expression that reaches into the admission request: the incoming resource's own fields (`request.object...`), the request envelope itself (`request.operation`, `request.namespace`), or a variable defined earlier in the rule.
- **`operator`** — the comparison to perform. See the table below.
- **`value`** — the right-hand side to compare against. A literal, or itself a variable.

If every condition across the whole `preconditions` block evaluates true, the rule body runs. If not, Kyverno skips the rule for this resource and moves on — no error, no report entry, just silence, exactly like a resource that never matched in the first place.

## The operator vocabulary

Kyverno's precondition operators (verified against the current [Kyverno documentation](https://kyverno.io/docs/policy-types/cluster-policy/preconditions/)) fall into three families:

| Operator | Meaning |
| --- | --- |
| `Equals` / `NotEquals` | Exact match / mismatch of a single scalar value. Not for arrays. |
| `AnyIn` | True if *any* of the keys (when `key` is itself a list) are found in `value`'s list. |
| `AllIn` | True if *all* of the keys are found in `value`'s list. |
| `AnyNotIn` | True if *any* of the keys are **not** found in `value`'s list. |
| `AllNotIn` | True if *all* of the keys are **not** found in `value`'s list. |
| `GreaterThan` / `GreaterThanOrEquals` | Numeric comparison. |
| `LessThan` / `LessThanOrEquals` | Numeric comparison. |
| `DurationGreaterThan` / `DurationGreaterThanOrEquals` | Comparison of Kubernetes/Go duration strings (`"5m"`, `"1h"`). |
| `DurationLessThan` / `DurationLessThanOrEquals` | Same, the other direction. |

`Equals`/`NotEquals` handle the overwhelming majority of real policies: "is this the right namespace," "is this the right operation," "does this label carry this exact value." The four `*In` operators exist for the case where either side (or both) is a list rather than a single value — checking a Pod's `containers[].image` list against an approved-registries list is the classic use, and they subsume what older Kyverno versions called plain `In`/`NotIn` (a single-value-against-a-list check is just the degenerate case of `AnyIn`/`AnyNotIn`). The numeric and duration operators cover comparisons a plain string `Equals` can't: "only enforce this rule if the cluster is less than 5 minutes into a maintenance window," for instance.

## The two keys every precondition eventually reaches for

Two `key` expressions do more work in real-world policies than everything else combined, and both come from the admission request rather than the resource's declared shape:

**`request.operation`** — the verb Kubernetes is performing: `CREATE`, `UPDATE`, `DELETE`, or `CONNECT`. This is the single most common precondition in production Kyverno policies, because a huge number of rules only make sense on creation:

```yaml
preconditions:
  all:
    - key: "{{ request.operation }}"
      operator: Equals
      value: "CREATE"
```

Without this, a validate rule checking (say) an image tag would also re-run every time someone updates an unrelated field on an already-running Pod — annoying at best, and actively wrong for rules whose intent was "gate what gets created," not "continuously re-litigate everything that already exists."

**Resource fields via `request.object`** — the incoming resource's own data, reached exactly the way `validate.pattern` reaches it:

```yaml
preconditions:
  all:
    - key: "{{ request.object.metadata.namespace }}"
      operator: NotEquals
      value: "kube-system"
```

This looks similar to what `match`/`exclude`'s `namespaces` selector already does — and for a plain namespace-name check, `exclude` is in fact the better tool (Part 2 covers exactly when to reach for one over the other). What makes `request.object` powerful in a precondition is that it isn't limited to the handful of fields `match` understands. Any field on the resource — a deeply nested spec value, an annotation, the *value* a label carries rather than just its presence — is fair game as a `key`.

> [!NOTE]
> Notice the `|| ''` in the skeleton policy's `key`: `"{{ request.object.metadata.labels.tier || '' }}"`. A Pod is not required to carry a `tier` label at all, and asking for a map key that doesn't exist would otherwise leave the expression with nothing to compare. The `||` operator supplies a fallback value — here, an empty string — so the condition still evaluates cleanly to `NotEquals "exempt"` (true) for a Pod that has no `tier` label, instead of erroring out. This idiom (`{{ <path that might not exist> || '<default>' }}`) is worth memorizing; you will reach for it constantly once you start writing conditions against optional fields.

Apply that skeleton policy in the playground and probe the boundary with three
Pods. The middle one is the point of the exercise: it violates the pattern and is
admitted anyway.

> [!TIP]
> **Try it — a skipped rule looks nothing like a lenient one**
>
> ```sh
> kubectl run bad-pod --image=nginx --restart=Never
> kubectl run exempt-pod --image=nginx --restart=Never --labels=tier=exempt
> kubectl run good-pod --image=nginx --restart=Never --labels=team=platform
> ```
>
> Expect something like:
>
> ```text
> resource Pod/default/bad-pod was blocked due to the following policies
>
> require-team-label-with-exemption:
>   check-team-label-unless-exempt: 'validation error: A team label is required on every Pod, unless it carries tier: exempt. rule check-team-label-unless-exempt failed at path /metadata/labels/team/'
>
> pod/exempt-pod created
> pod/good-pod created
> ```
>
> `exempt-pod` has no `team` label either — by the pattern alone it should have
> failed exactly like `bad-pod`. The precondition evaluated to false for it, so
> `validate` never ran at all.

That distinction matters more than it first appears. A *lenient pattern* would
have examined `exempt-pod` and decided it was acceptable; a *false precondition*
means nothing examined it. You can see the difference in the reports: a skipped
rule produces a `skip` result rather than a `pass`, so "this rule found nothing
wrong" and "this rule never looked" stay distinguishable after the fact.
