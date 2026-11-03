# Summary

A precondition decides whether a rule runs at all. When the preconditions evaluate to false, the rule body is skipped and the request passes that rule. This is different from a failed validation. Preconditions use the same `key`, `operator` and `value` syntax as deny conditions, in an `all` block or an `any` block, and `request.operation` lets a rule apply only to verbs such as `CREATE`.

The `all` block requires every condition and the `any` block requires one, so the wrong choice makes a rule too loose or too strict. Many conditions can be written in `match` or `exclude`, such as label equality, operations and namespace names. Use `match` and `exclude` for those, because Kyverno can filter before it evaluates anything. Use `preconditions` for anything that needs a variable, a numeric comparison, or a value from the body of the resource.

Key facts:

- False preconditions skip the rule; they do not fail the request.
- `all` means every condition, `any` means at least one.
- Prefer `exclude` for plain namespace or label filters.

<!-- astrona:playground:destroy -->
