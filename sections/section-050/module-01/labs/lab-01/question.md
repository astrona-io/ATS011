# Question

Solve this question against the `kind` cluster provisioned for this lab (Kyverno is already installed and running in the `kyverno` namespace).

Write and apply a `ClusterPolicy` with a `generate` rule that governs Namespace creation cluster-wide:

1. The rule must trigger on `kind: Namespace` — every newly created Namespace is the trigger.
2. It must generate (using literal data, **not** a clone) a `NetworkPolicy` named `default-deny-ingress` into the new Namespace, with:
   - `spec.podSelector: {}` (an empty selector — it applies to every Pod in the Namespace)
   - `spec.policyTypes: ["Ingress"]`
3. Do not restrict the rule to a single namespace; it must apply to every namespace created on the cluster (excluding Kyverno's own system namespaces is fine and recommended, but not required for grading).

You may name the policy and its rule however you like.
