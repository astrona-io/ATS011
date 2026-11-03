# Summary

By default a generate rule reacts only to new triggers. The setting `generate.generateExisting: true` also applies the rule to resources that already exist, and Kyverno does that work in the background. Because it can change many namespaces at once, a safe rollout first applies the rule without it, then enables it on a narrow match, then widens the match.

`generateExisting` is about the past: does the rule reach what is already here? `synchronize` is about the future: is the downstream kept equal to its source? Either one can be used without the other.

When a policy is deleted, Kyverno deletes the resources that the policy generated. The setting `orphanDownstreamOnPolicyDelete: true` keeps them instead. Kubernetes garbage collection does not do this work. Kyverno tracks its downstream resources itself, which is why the behaviour is a field you can set. Keep the downstream when its absence is worse than its being unmanaged.

Key facts:

- `generateExisting` reaches existing resources through the background controller.
- Deleting the policy deletes generated resources by default.
- `orphanDownstreamOnPolicyDelete: true` keeps them.

<!-- astrona:playground:destroy -->
