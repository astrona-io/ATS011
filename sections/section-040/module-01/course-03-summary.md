# Summary

A `mutate` rule changes a resource during admission. With `patchStrategicMerge`, the rule contains a partial resource that Kyverno merges into the incoming one. A list needs the `(name)` anchor to reach every element. Without it the merge cannot match list items by their key.

If the incoming resource already sets a value that the rule also sets, the rule value wins. Mutate rules run before validate rules, so a validate rule can rely on a field that a mutate rule injected in the same request. That order is a guarantee of the rule types, not a result of the rule names.

To patch resources that already exist, `mutateExistingOnPolicyUpdate` with a `targets` block applies the change when the policy is created or updated. Kyverno needs RBAC permission to change the target kinds before it accepts such a policy. Even then, Kubernetes allows only some fields to change after creation, and the patch cannot override that.

Key facts:

- Use `(name)` to merge list elements by name.
- Mutate runs before validate in one request.
- Mutating existing resources needs RBAC for the target kind.

<!-- astrona:playground:destroy -->
