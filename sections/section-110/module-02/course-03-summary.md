# Summary

The `policies.kyverno.io` family has five kinds, and each does one job: `ValidatingPolicy`, `MutatingPolicy`, `GeneratingPolicy`, `ImageValidatingPolicy` and `DeletingPolicy`. They replace the rule types of a `ClusterPolicy`. One kind per job keeps each policy short and makes its purpose obvious, but a policy that needs several rule types becomes several objects.

A `MutatingPolicy` changes a resource with CEL and runs at admission. An `ImageValidatingPolicy` splits a `verifyImages` entry into top-level fields, names its attestors, and makes `cosign` or `notary` an explicit choice. A `DeletingPolicy` is the CEL counterpart of a cleanup policy. It uses the same cron schedule, the same cleanup controller and the same RBAC, but its expressions read `object` instead of `target`. The `apiVersion` of an object tells you which family it belongs to.

Key facts:

- Five kinds, one job each.
- `DeletingPolicy` reads `object`; a cleanup policy reads `target`.
- The `apiVersion` identifies the family.

<!-- astrona:playground:destroy -->
