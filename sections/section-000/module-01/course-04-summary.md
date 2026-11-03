# Summary

A Kyverno policy is an object with a list of rules. A `ClusterPolicy` applies to the whole cluster. A namespaced `Policy` lives in one namespace and only affects resources in that namespace, so it cannot govern other namespaces or cluster-scoped kinds. Every rule, whatever its type, has a name, a `match` block, an optional `exclude` block and optional `preconditions`, and then exactly one body: `validate`, `mutate`, `generate` or `verifyImages`.

The failure action decides what a failed validation does. `Enforce` rejects the request. `Audit` admits it and records the failure in a policy report. The action can be set for the whole policy, for a single rule, or for chosen namespaces with an override list, which lets a team audit a new rule everywhere and enforce it in one namespace first.

When one request matches rules of several types, Kyverno runs all mutate rules first, then all validate rules, and generates resources after the response. The order of rules of the same type is not defined, so overlapping rules must be written so that the order does not matter.

An exemption can take three forms. `exclude` removes resources by structure, such as a namespace or a label. `preconditions` skip a rule based on a value in the request. A `PolicyException` object lets another team grant the exemption without editing the policy.

Key facts:

- A namespaced `Policy` cannot match resources outside its own namespace.
- Mutate rules run before validate rules for the same request.
- `Audit` never blocks a request.

<!-- astrona:playground:destroy -->
