# Question

Solve this question against the `kind` cluster provisioned for this lab (Kyverno is already installed and running in the `kyverno` namespace). The namespace `team-a` already exists and already has **two** Pods running in it before you write anything — that's deliberate, so you can prove your policy reacts to real, live cluster state.

Write and apply a `ClusterPolicy` that enforces a per-namespace Pod quota, using **live data fetched from the Kubernetes API at evaluation time** — not a number you count by hand and hardcode:

1. The policy's `validationFailureAction` must be `Enforce`.
2. The rule must match every `Pod`, cluster-wide — do not restrict it to `team-a` or any other single namespace.
3. Restrict the rule's `match` to the `CREATE` operation only (`match.resources.operations: [CREATE]`). Do not leave `operations` unset.
4. Exclude the `kube-system`, `kyverno`, and `local-path-storage` namespaces from the rule, so you don't risk blocking control-plane or Kyverno's own Pods.
5. Use a `context.apiCall` entry that calls the Kubernetes API to count how many Pods **already exist in the namespace of the Pod currently being admitted** (`urlPath` should reference `{{request.namespace}}`, not a hardcoded namespace name).
6. Deny the incoming Pod if that count is already **3 or more** — i.e. a namespace may hold at most 3 Pods, and the check must use the value your `context.apiCall` fetched, not a value written elsewhere in the policy.

> [!NOTE]
> Requirement 3 is not busywork. A rule with no `operations` restriction also evaluates on DELETE. Since the quota check compares "is the namespace's live Pod count already at or over the limit," an over-limit namespace can never have any of its own Pods deleted through the normal API if the rule isn't scoped to `CREATE` — every delete attempt re-runs the same `apiCall`, sees the namespace is still over quota, and denies the delete too, which can hang a `kubectl delete ns` (or the whole namespace-deletion controller) indefinitely. Scoping to `CREATE` avoids this: the quota still governs whether a new Pod is admitted, but it has no opinion about deleting Pods that already exist.

You may name the policy, its rule, and the `context` entry however you like.
