# Question

Kyverno is installed and the namespace `cel-lab` exists. Use the CEL-native `policies.kyverno.io/v1` API family.

1. Create a `MutatingPolicy` named `add-managed-by` that matches Pod CREATE requests and sets the label `managed-by: kyverno-mutatingpolicy` with an `ApplyConfiguration` mutation. A Pod created in `cel-lab` must carry the label.
2. Create a `DeletingPolicy` named `sweep-ephemeral` that runs every minute (`schedule: "* * * * *"`), matches Pods, and has one named condition whose CEL expression is true only for Pods that carry the label `lifecycle: ephemeral`. Guard the expression with `has()` so that Pods without labels do not cause an error.
