# Summary

Common Expression Language (CEL) is a small expression language that cannot loop forever, which makes it safe to run inside the API server. It suits checks that a pattern cannot say, such as every container having a memory limit or a value staying under a limit. Kyverno binds values such as `object` and `oldObject` into the expression, and `variables` entries are evaluated before the expressions that use them.

A `ValidatingPolicy` has `matchConstraints`, `validations` and `validationActions`, and each maps to a concept from `ClusterPolicy`. `matchConditions` filter requests first. `has()` guards optional fields, but a rule that denies a Pod without a field can still make Pods undeletable if it also runs on delete. Kyverno prints a type-check warning at apply time that predicts the admission failure.

Autogen works for these policies too, with the path rewriting done inside the CEL strings. When `autogen.validatingAdmissionPolicy` is enabled, Kyverno generates a native `ValidatingAdmissionPolicy` and binding, and the API server enforces the policy without a webhook. A rejection message shows which of the two blocked the request.

Key facts:

- `has()` tests presence, not truthiness.
- A native policy has no webhook but no external lookups.
- `matchConditions` run before the validations.

<!-- astrona:playground:destroy -->
