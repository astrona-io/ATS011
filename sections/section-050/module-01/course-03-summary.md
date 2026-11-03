# Summary

A `generate` rule creates a new resource when another resource appears. The classic trigger is a `Namespace`, so that every new namespace receives a default `NetworkPolicy` or a shared `ConfigMap` without anyone having to remember. With `generate.data`, the rule contains the full manifest. With `generate.clone`, Kyverno copies an existing resource from another location.

The `synchronize` setting decides whether the copy stays a copy. With `synchronize: true`, Kyverno propagates changes from the source to the clones, reverts direct edits of the generated resource, and recreates it when it is deleted. Deleting the trigger namespace removes its generated resources through the normal namespace deletion, not through a special Kyverno action.

Key facts:

- `generate.data` writes a literal manifest; `generate.clone` copies a source.
- `synchronize: true` keeps the downstream equal to its source.
- A Namespace is the usual trigger.

<!-- astrona:playground:destroy -->
