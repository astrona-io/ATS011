# Section 020 Knowledge Check: Preconditions

Test your diagnostic reasoning before attempting the lab. Try to answer each question yourself before expanding the explanation.

---

**1.** A rule has `match` selecting all Pods, and a `preconditions.all` block that evaluates to `false` for a particular incoming Pod. What happens to that Pod's `validate.pattern`?

<details>
<summary>Show Answer</summary>

It never runs. When `preconditions` evaluates `false`, Kyverno skips the entire rule body — `validate`, `mutate`, or `generate`, whichever the rule has — for that resource, exactly as if `match` itself had excluded it. This is different from the pattern "passing": the pattern is never even consulted.
</details>

---

**2.** A precondition's `key` is `"{{ request.object.metadata.labels.owner }}"`, and the incoming Pod has no `owner` label at all. What is the most likely outcome, and how would you fix it?

<details>
<summary>Show Answer</summary>

Without a default, the expression has nothing to resolve to when the key is genuinely absent, which is a common source of evaluation errors on optional fields. The standard fix is the `||` default-value idiom: `"{{ request.object.metadata.labels.owner || '' }}"`, which falls back to an empty string when the label is missing, letting the surrounding `Equals`/`NotEquals` comparison evaluate cleanly either way.
</details>

---

**3.** True or false: `match.resources` can filter on the admission operation (`CREATE`, `UPDATE`, etc.) on its own, without any help from `preconditions`.

<details>
<summary>Show Answer</summary>

True. `match.resources.operations` (and the identical field under `exclude.resources`) accepts a literal list like `[CREATE, UPDATE]`. This is a genuine overlap with what a `request.operation` precondition can do — for a rule that only ever needs to scope itself to specific verbs and nothing else, `match`/`exclude`'s `operations` field is the simpler, cheaper tool.
</details>

---

**4.** Given that `match`/`exclude` can filter by label value (via `selector`) and by operation (via `operations`), what is the one restriction that `preconditions` doesn't share, and that ultimately decides which cases only `preconditions` can handle?

<details>
<summary>Show Answer</summary>

`match` and `exclude` fields must be static literals — Kyverno does not support `{{ }}` variable substitution inside a `match` or `exclude` statement at all. `preconditions` exists specifically to evaluate variable expressions: JMESPath into `request.object`, `request.operation`, context variables, and comparison operators like `GreaterThan` or `AnyIn`. Any condition that needs a computed or numeric comparison — "is this field's value greater than X," "does this match something fetched from an API call" — is therefore only reachable through `preconditions`, no matter how the `match`/`exclude` block is written.
</details>

---

**5.** A rule's `preconditions` block is:

```yaml
preconditions:
  any:
    - key: "{{ request.object.metadata.labels.tier || '' }}"
      operator: Equals
      value: "critical"
    - key: "{{ request.namespace }}"
      operator: Equals
      value: "production"
```

A Pod is submitted in the `staging` namespace with no `tier` label. Does the rule body run?

<details>
<summary>Show Answer</summary>

No. `any` requires at least one condition to be true, and neither is: the Pod's `tier` isn't `critical` (it's empty, thanks to the `||` default), and its namespace isn't `production`. Both conditions must fail for `any` to be false — if either one had matched, the rule body would have run.
</details>

---

**6.** You meant to write "only enforce this rule when the Pod is in namespace `prod` AND the operation is `CREATE`," but you wrote `preconditions.any` instead of `preconditions.all` by mistake. What actually happens to the rule's behavior?

<details>
<summary>Show Answer</summary>

The rule becomes far looser than intended. With `any`, the rule body now runs whenever *either* condition is true on its own — every `CREATE` in any namespace, and every operation (including `UPDATE`/`DELETE`) inside `prod`. What was meant to be a narrow AND-gated rule silently turns into a broad OR-gated one. This is exactly the kind of bug that passes a quick glance at the YAML but fails the first time someone updates an unrelated field on a `prod` Pod and gets unexpectedly blocked (or, worse, the reverse: a rule meant to be strict lets far more through than intended).
</details>

---

**7.** A `preconditions.all` block has two conditions: `request.operation Equals "CREATE"` and `request.namespace NotEquals "trusted-automation"`. An existing, already-compliant Pod in namespace `team-ns` has its `team` label removed via `kubectl label pod NAME team-`. Does the rule reject this?

<details>
<summary>Show Answer</summary>

No. `kubectl label ... team-` sends an `UPDATE` request, not a `CREATE`. That makes the first condition in the `all` block false, which makes the whole `preconditions.all` block false (AND requires every condition to hold), which means the rule is skipped entirely for this request — `validate.pattern` is never consulted, so the label can be removed even though the resulting Pod would fail the pattern if it were being freshly created. This is precisely why operation-scoped rules using `CREATE`-only preconditions do not protect against a compliant resource being edited into non-compliance later — that gap is what background scanning (Section 030) exists to catch.
</details>

---

**8.** Why might a real-world policy still prefer folding an operation check and a namespace check into one `preconditions.all` block, even though `match.resources.operations` plus `exclude.resources.namespaces` could express the identical two conditions on their own?

<details>
<summary>Show Answer</summary>

Two practical reasons. First, the moment a rule's gating logic needs even one condition `match`/`exclude` truly cannot express (a numeric threshold, a field deep in `spec`, a context-derived value), that condition has to live in `preconditions` — and keeping *all* of the rule's "when does this even apply" logic in one block, rather than splitting related conditions across `match`, `exclude`, and `preconditions`, makes the policy easier for the next reader to audit. Second, `request.operation` and `request.namespace` compared with `Equals`/`NotEquals` inside `preconditions.all` is the exact shape you need fluency with for cases that don't have a `match`/`exclude` shortcut, so recognizing and writing it correctly matters independent of whether a given instance happens to have an alternative.
</details>
