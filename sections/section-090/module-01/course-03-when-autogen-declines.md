# Part 3: When Autogen Declines, and When It Gets It Wrong

Parts 1 and 2 covered autogen doing what you asked. This part covers the two cases where the result is not what you expected: rules for which autogen produces nothing at all, and rules where it produces something confidently useless.

Both are silent. Neither raises an error, and both leave a policy that looks installed and healthy while protecting less than you think.

## When autogen doesn't fire — and when it fires but gets it wrong

**A `match` selecting more than one kind disables autogen for that rule entirely.** Take the same rule, but add `Namespace` alongside `Pod` in the same `match.any` entry:

```yaml
rules:
  - name: check-team-label-multi
    match:
      any:
        - resources:
            kinds:
              - Pod
              - Namespace
    validate:
      message: "A team label is required."
      pattern:
        metadata:
          labels:
            team: "?*"
```

```bash
kubectl get clusterpolicy multi-kind-match -o yaml
# status:
#   autogen: {}
```

Empty — not partially generated, not generated-for-Pod-only-since-Namespace-doesn't-have-a-controller-shape — completely absent. Autogen's rule is simple: the moment a `match` (or `exclude`) entry names any kind other than `Pod`, Kyverno considers the rule's intent too broad to safely rewrite, and skips autogen for that rule altogether. If you need both behaviors, write two separate rules — one matching only `Pod` (which autogen will happily expand) and one matching only `Namespace` (which was never a candidate for autogen in the first place).

**Autogen fires mechanically, without understanding your pattern's meaning.** It doesn't parse what your pattern is "trying to say" — it applies a fixed text-level rewrite (wrap everything under `spec` inside `spec.template`, or `spec.jobTemplate.spec.template` for CronJob) no matter what was already there. Write a Pod-only rule whose pattern already anticipates a template-shaped path — a mistake that's easy to make if you're thinking about the Deployment you actually intend to protect while writing a Pod-matched rule:

```yaml
rules:
  - name: weird-template-pattern
    match:
      any:
        - resources:
            kinds:
              - Pod
    validate:
      message: "test"
      pattern:
        spec:
          template:
            spec:
              containers:
                - image: "?*"
```

```bash
kubectl get clusterpolicy already-template-path -o yaml
# status:
#   autogen:
#     rules:
#     - name: autogen-weird-template-pattern
#       validate:
#         pattern:
#           spec:
#             template:
#               spec:
#                 template:      # <- doubled
#                   spec:
#                     containers:
#                     - image: ?*
```

The rewrite blindly nested your already-`spec.template`-shaped pattern one level deeper, producing `spec.template.spec.template.spec.containers` — a path that will never exist on a real Deployment. The generated rule is silently useless against every Pod-controller kind, while your original rule (evaluated against bare Pods, where `spec.template` genuinely doesn't exist) continues to behave however that odd pattern happens to behave. Autogen did exactly what it always does — a fixed mechanical rewrite — it just had nothing sensible to rewrite here. The lesson: write Pod rules against the Pod's own shape (`spec.containers`, `metadata.labels`, …), never against the shape you expect autogen to eventually produce; let the rewrite do that part for you.

## Why declining is the only safe answer

It is tempting to read the multi-kind refusal as a missing feature. It is closer to the opposite.

Autogen's entire job is a **mechanical path rewrite**: take the field paths in a rule written against a Pod, and move them under `spec.template` (or `spec.jobTemplate.spec.template`). That rewrite is only well-defined because the source shape is known — a Pod, whose spec sits at the document root.

```text
  rule matches Pod only              rule matches Pod AND Namespace
  ---------------------              ------------------------------
  source shape: Pod                  source shape: ...which one?
  rewrite: spec -> spec.template     a Namespace has no Pod template
  result: well-defined               result: undefined
```

Given `kinds: [Pod, Namespace]`, there is no answer to "what should `metadata.labels` become on the controller version of this rule", because the rule is no longer unambiguously about Pods. Kyverno's options were to guess, to generate something partial, or to decline. It declines — which is the only one of the three that cannot silently produce a rule enforcing the wrong thing.

The same reasoning explains the second failure. Autogen does not parse your pattern for meaning; it applies the rewrite positionally. A pattern already written against `spec.template` is, as far as the rewriter is concerned, just a pattern — so it gets wrapped again.

## Checking, rather than assuming

Both failures are invisible in the policy you wrote, so the check is always the same: read what was actually generated.

```bash
kubectl get clusterpolicy <name> -o jsonpath='{.status.autogen}'
```

Three outcomes and what each means:

| What you see | Meaning |
| :--- | :--- |
| Two rules, one grouping six kinds and one for CronJob | autogen fired normally |
| `{}` or empty | autogen declined — check for a multi-kind `match`, or an `autogen-controllers: none` annotation |
| Rules present, but a path with a doubled segment | autogen fired on a pattern that already anticipated a controller shape |

The third is the one worth reading carefully rather than glancing at, because a generated rule with a nonsense path looks structurally identical to a correct one.


## Section recap

Autogen declines entirely when a rule's `match` or `exclude` names any kind besides `Pod` — `status.autogen` comes back empty, with no error to notice. And it fires without understanding your pattern, performing the same fixed path rewrite regardless, so a pattern that already anticipated a controller's shape is rewritten into a path no resource has. Both failures look identical from outside: a policy that installed cleanly and protects less than it appears to. The defence is the same in each case — write the rule against a Pod's own native shape, one kind per rule, and read `status.autogen` rather than assuming it.
