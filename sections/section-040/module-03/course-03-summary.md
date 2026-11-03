# Summary

A plain patch states the final value, so it overwrites whatever the owner chose. The add-if-not-present anchor `+(field)` writes a field only when it is missing. It is the right tool for defaults such as a `team` label or `automountServiceAccountToken: false`, because an explicit value from the owner is kept.

Because it acts only when the field is absent, a `+()` patch is safe to run again on every UPDATE. It never compounds. The price is that it never corrects a wrong value, so a rule that must force a value uses a plain field. A field that the API server defaults itself is already present when the webhook runs, so `+()` does nothing there.

A conditional anchor such as `(name): "sidecar-*"` makes a list element a filter. Only elements whose value matches, wildcards included, receive the patch. Others are skipped, not rejected. Only `patchStrategicMerge` supports conditional anchors, and they cannot be nested.

Combining the two selects the elements with `()` and defaults a field on them with `+()`. The result is a default for a subset of elements that still respects what the owner set.

Key facts:

- `+(field)` writes only when the field is missing.
- `+()` rules are idempotent by construction.
- `(name): "pattern"` selects list elements and skips the rest.
- Conditional anchors work only in `patchStrategicMerge`.

<!-- astrona:playground:destroy -->
