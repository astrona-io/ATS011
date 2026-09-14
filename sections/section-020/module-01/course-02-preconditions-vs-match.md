# Part 2: Preconditions vs. match/exclude, and all vs. any

## First, an honest admission: match/exclude is more capable than it looks

Before drawing the line between `preconditions` and `match`/`exclude`, it's worth correcting a natural but wrong assumption: that `match`/`exclude` can only filter by kind and namespace. In fact `match.resources` (and the identically-shaped `exclude.resources`) also accepts:

```yaml
match:
  any:
    - resources:
        kinds:
          - Pod
        operations:
          - CREATE
        selector:
          matchExpressions:
            - key: tier
              operator: NotIn
              values:
                - exempt
```

That single block already does *both* things Part 1's lab policy needed a precondition for: `operations: [CREATE]` restricts the rule to creation only, and the `selector.matchExpressions` entry excludes anything labeled `tier: exempt` (`NotIn` — the same `matchExpressions` vocabulary as a plain Kubernetes label selector: `In`, `NotIn`, `Exists`, `DoesNotExist`). So if that's true, why does this section exist at all — why not always reach for `match`/`exclude` and skip `preconditions` entirely?

## The one restriction that decides everything

`match` and `exclude` fields are **static**. Per Kyverno's own documentation: *"variable substitution is not currently supported in `match` or `exclude` statements."* Every field you write there — a kind, a namespace glob, a label value, an operation name — has to be a literal you typed in the YAML. There is no `{{ }}` anywhere in a `match` or `exclude` block.

`preconditions` has the opposite property: its whole reason for existing is to evaluate `{{ }}` expressions — JMESPath reaching into `request.object`, `request.operation`, variables from earlier in the rule, even data fetched from other objects via context (Section 070 covers API-call and ConfigMap context in depth). Every `key` you've written so far in this module has been a variable expression for exactly this reason.

That one restriction is the entire boundary:

| Question you need answered | Can `match`/`exclude` do it? | Can `preconditions` do it? |
| --- | --- | --- |
| Is this a Pod? | Yes (`kinds`) | Yes, but pointless — use `match` |
| Is this in namespace `staging`? | Yes (`namespaces` glob) | Yes, via `request.namespace` |
| Does it carry label `tier: exempt`? | Yes (`selector.matchLabels`/`matchExpressions`) | Yes, via `request.object.metadata.labels.tier` |
| Is this a `CREATE`? | Yes (`operations`) | Yes, via `request.operation` |
| Is `spec.replicas` greater than 3? | **No** — no numeric comparison exists in `match`/`exclude`, and no field reaches `spec` at all | Yes, via `GreaterThan` |
| Does this container's declared `resources.limits.memory` exceed `512Mi`? | **No** — same reason: no path into `spec`, no comparison operator | Yes |
| Is this the same value my earlier `context` API call returned? | **No** — `match`/`exclude` cannot reference variables or context at all | Yes |

The first four rows are things both tools can express — which is exactly why the module lab's `tier: exempt` exemption *could* have been written as an `exclude.selector` instead of a `preconditions` block, and why the capstone's `CREATE`-only, non-`trusted-automation` gate could likewise have been written as `match.resources.operations: [CREATE]` plus `exclude.resources.namespaces: [trusted-automation]`. Both labs deliberately use `preconditions` anyway, for two reasons worth internalizing:

1. **The mechanic itself is exam-relevant and reads identically to genuinely inexpressible cases.** A precondition comparing `request.operation` or a label's value looks exactly like one comparing `spec.replicas` with `GreaterThan` — you need fluency with the shape regardless of which specific condition happens to have a `match`/`exclude` equivalent.
2. **The moment any single condition in your rule needs a value comparison `match`/`exclude` can't do, the cleanest real-world habit is to put the *whole* gate in one `preconditions` block**, rather than splitting logically-related conditions across three different fields (`match`, `exclude`, and `preconditions`) that each have their own partial, overlapping vocabulary. A reviewer reading your policy six months from now should be able to find "when does this rule actually apply" in one place.

The last three rows in the table are the real, hard boundary: anything that requires reading an actual field value out of the resource body (not just its identity metadata) and comparing it — numerically, against another variable, against context — has to be a precondition. `match`/`exclude` fundamentally cannot look past a resource's kind/name/namespace/labels/annotations/operation, and it can never hold a `{{ }}` expression to make that comparison dynamic.

## all vs. any: AND and OR, and why the capstone needs both ideas at once

`preconditions.all` and `preconditions.any` mirror `match.any`'s OR exactly, but note the asymmetry with `match`: a `match`/`exclude` block picks *either* `any` *or* `all` for its list of resource descriptors, while `preconditions` genuinely supports both keys independently (and lets you nest one inside the other for compound logic). For everyday policies, though, you will use one or the other, not both, and the choice changes the rule's behavior completely:

```yaml
# ALL — every condition must be true. The rule tightens.
preconditions:
  all:
    - key: "{{ request.operation }}"
      operator: Equals
      value: "CREATE"
    - key: "{{ request.namespace }}"
      operator: NotEquals
      value: "trusted-automation"
```

```yaml
# ANY — at least one condition must be true. The rule loosens.
preconditions:
  any:
    - key: "{{ request.object.metadata.labels.tier || '' }}"
      operator: Equals
      value: "critical"
    - key: "{{ request.object.metadata.namespace }}"
      operator: Equals
      value: "production"
```

Read the `all` block as a checklist: the rule only fires once *every single item* is checked off — miss one, and the whole rule is skipped. Read the `any` block as a trigger list: the rule fires the moment *any single item* fires, regardless of the rest. Mixing them up is a common, subtle bug: writing `any` when you meant "these two conditions must both hold" silently makes your rule fire far more often than intended, because now either condition alone is enough.

The capstone in this section is built specifically to force you to reach for `all`: the rule must apply on `CREATE` **and** outside `trusted-automation` — drop either half, or accidentally write `any` instead of `all`, and the rule starts firing on `UPDATE` requests (or inside the exempted namespace) that it was supposed to leave alone. Section 030 revisits `any`/`all` again from a different angle — background scans, which re-evaluate `preconditions` against resources that already exist, not just new admission requests.

The cheapest way to feel that asymmetry is to apply the `all` block above and
then attack it from both sides: break the operation half, then break the
namespace half, and see the rule go quiet either way.

> [!TIP]
> **Try it — one false condition is enough to skip the rule**
>
> ```sh
> kubectl create ns trusted-automation
> kubectl create ns team-ns
>
> kubectl run good-create -n team-ns --image=nginx --restart=Never --labels=team=platform
> kubectl label pod good-create -n team-ns team-
> kubectl get pod good-create -n team-ns -o jsonpath='{.metadata.labels}'
>
> kubectl run bad-create -n team-ns --image=nginx --restart=Never
> kubectl run auto-pod -n trusted-automation --image=nginx --restart=Never
> ```
>
> Expect something like:
>
> ```text
> pod/good-create created
> pod/good-create unlabeled
> 
> team-label-on-create-outside-automation:
>   check-team-label: 'validation error: A team label is required on every Pod. rule check-team-label failed at path /metadata/labels/team/'
> pod/auto-pod created
> ```
>
> Four probes, three outcomes. `good-create` passed on CREATE. Stripping its
> label was an UPDATE, so the first condition went false and the rule never
> re-checked anything — the `jsonpath` query comes back empty, meaning a Pod now
> runs with no `team` label in a namespace with no exemption. `bad-create` shows
> the rule is still very much alive on CREATE. And `auto-pod`, identically
> non-compliant, sails through because the *second* condition went false.

That empty label output is the whole lesson. Preconditions do not grade on a
curve: with `all`, a single `false` from either condition skips the entire rule,
and the two halves are indistinguishable from the outside — both just produce
silence. If you need to know *why* a rule stayed quiet, the reports are where a
`skip` result is recorded; the admission response tells you nothing, because
from the requester's point of view nothing happened.
