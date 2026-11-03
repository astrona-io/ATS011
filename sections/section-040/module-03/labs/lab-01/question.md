# Question

Kyverno is installed and the namespace `anchor-lab` exists. Write a `ClusterPolicy` named `mutation-anchors` with `background: false` and mutate rules for Pods in `anchor-lab`, so that:

1. A Pod without a `team` label gets `team: platform`. A Pod that already has a `team` label keeps its own value.
2. A Pod that does not set `spec.automountServiceAccountToken` gets `false`. A Pod that sets it to `true` keeps `true`.
3. Every container whose name starts with `sidecar-` gets `securityContext.readOnlyRootFilesystem: true` when it does not set that field itself. A sidecar that sets it to `false` keeps `false`.
4. Containers whose names do not start with `sidecar-` are not changed.
