# Question

Solve this question against the `kind` cluster provisioned for this lab (Kyverno is already installed and running in the `kyverno` namespace).

Write and apply a `ClusterPolicy` that governs every Pod cluster-wide:

1. Use `mutate.patchesJson6902` (RFC 6902 JSON Patch) — not `patchStrategicMerge` — to append an environment variable to the **first container** (index `0`) of every incoming Pod:
   - `name`: `INJECTED_BY_POLICY`
   - `value`: `"true"`
2. The rule must work correctly whether the first container already has an `env` array or has none at all:
   - If `env` already exists with entries, your new entry must be appended — existing entries must survive untouched.
   - If `env` does not exist at all, it must be created containing just your new entry.
3. Do not restrict the policy to a single namespace; it must apply cluster-wide.

You may name the policy and its rule however you like.
