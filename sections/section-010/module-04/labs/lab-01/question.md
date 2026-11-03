# Question

Kyverno is installed and the namespace `pss-lab` exists. Write a `ClusterPolicy` named `pss-baseline` with `validationFailureAction: Enforce` and `background: false` with one `validate.podSecurity` rule for Pods in `pss-lab`:

1. Enforce the `baseline` level, with `version: latest`.
2. Relax **only** the `Capabilities` control, and only for containers whose image matches `registry.example.com/net-tool*`.

A privileged Pod must be rejected. A Pod that adds `NET_ADMIN` must be rejected unless its image is `registry.example.com/net-tool:1`.
