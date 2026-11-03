# Summary

Variables written as `{{ }}` let a rule use values that exist only at evaluation time. They are allowed in most string fields of a rule, but not in the keys of a `match` block. `request.object`, `request.oldObject`, `request.operation`, `request.namespace` and `request.userInfo` describe the incoming request, so a rule can react to who is acting and what changed.

A `context.apiCall` entry asks the Kubernetes API for data and shapes the response with `jmesPath`. A `deny` rule can then compare the result with a limit that is not written in the policy. If the call fails, the rule fails by default. A `default` value in the entry gives the rule a fallback and changes that outcome.

Key facts:

- `{{ }}` expressions are resolved at evaluation time.
- `apiCall` plus `jmesPath` turns API data into a variable.
- A `default` handles a failed lookup.

<!-- astrona:playground:destroy -->
