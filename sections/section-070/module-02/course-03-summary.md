# Summary

A context entry fetches or computes a value for a rule. The five entry types are `apiCall`, `configMap`, `variable`, `imageRegistry` and `globalReference`, and the right one depends on where the fact lives. A `configMap` entry reads policy data that changes more often than the policy. Kyverno re-reads it when it changes, so editing the ConfigMap changes the behaviour without a new policy.

A `variable` entry computes an intermediate value that conditions and messages can reuse. Entries are evaluated in order, so a later entry can use an earlier one. An `imageRegistry` entry fetches image metadata that the Kubernetes API does not have, at the cost of an external call during admission. A `GlobalContextEntry` performs an expensive lookup on a schedule and caches the result, which trades freshness for cost and is read with `globalReference`.

Key facts:

- Context entries are evaluated in order.
- A `configMap` entry keeps data outside the policy.
- `globalReference` reads a cached lookup.

<!-- astrona:playground:destroy -->
