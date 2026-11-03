# Summary

The `validate.podSecurity` rule checks a Pod against one of the three Pod Security Standards: `privileged`, `baseline` and `restricted`. The rule takes a `level` and a `version`. Pinning the version keeps the checks stable when a new Kubernetes release changes the standard, and `latest` follows the newest definition. A failure message lists every control that failed, so one rejection can name several problems.

When a workload needs one exception, `exclude` relaxes a single control instead of dropping the whole profile. The exclusion names a `controlName`, and it can be narrowed with `images`, or with `restrictedField` and `values`. The exemption stays small, documented and easy to review.

Kubernetes has its own Pod Security Admission controller that applies the same standards per namespace with labels. It has no per-control exceptions. The Kyverno rule has finer control and the built-in controller needs no extra software, so teams often run them together.

Key facts:

- `exclude` takes a `controlName` from the standard's own control list.
- The failure message names each failed control.
- Pin `version` to keep behaviour stable across upgrades.

<!-- astrona:playground:destroy -->
