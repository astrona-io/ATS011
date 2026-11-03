# Summary

A `pattern` describes a shape. A `deny` rule describes a test. The rule has a `conditions` block, and the request is rejected when the conditions evaluate to true. This is the opposite polarity of a pattern, which passes when the shape matches, and it is the most common source of backwards deny rules.

Conditions use a `key`, an `operator` and a `value`. Inside the block, `all` requires every condition to be true and `any` requires at least one. The operator names are case sensitive and fall into four families: equality, numeric, set and duration. The set operators are a grid of `AnyIn`, `AllIn`, `AnyNotIn` and `AllNotIn`, and the difference between Any and All only matters when the key resolves to a list. Numeric operators understand quantities such as `Mi` and `Gi`, but `Equals` compares strings.

A deny rule can loop with `foreach` to test each list element, and the message can quote the offending value with a `{{ }}` variable. A fallback such as `|| ''` keeps an optional field from turning a condition into an evaluation error.

Key facts:

- A deny rule rejects when its conditions are true.
- `foreach` plus `deny` tests every element independently.
- Add `|| ''` to optional fields used in a `key`.

<!-- astrona:playground:destroy -->
