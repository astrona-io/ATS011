# Solution Guide: Live Pod-Quota Lab

This guide builds one `ClusterPolicy`, one rule, with a `context.apiCall` that fetches a live Pod count per namespace and a `validate.deny.conditions` check that uses it.

---

## Step 1: Write the policy

Create `policy.yaml`:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: pod-quota-per-namespace
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: limit-pods-per-namespace
      match:
        any:
          - resources:
              kinds:
                - Pod
              operations:
                - CREATE
      exclude:
        any:
          - resources:
              namespaces:
                - kube-system
                - kyverno
                - local-path-storage
      context:
        - name: nsPodCount
          apiCall:
            urlPath: "/api/v1/namespaces/{{request.namespace}}/pods"
            jmesPath: "items | length(@)"
      validate:
        message: >-
          Namespace "{{request.namespace}}" already has {{nsPodCount}}
          Pod(s); the limit is 3 per namespace.
        deny:
          conditions:
            any:
              - key: "{{nsPodCount}}"
                operator: GreaterThanOrEquals
                value: 3
```

A few choices worth explaining:

- **`urlPath: "/api/v1/namespaces/{{request.namespace}}/pods"`** — this is the exact Kubernetes API path for listing Pods in one namespace. `{{request.namespace}}` is substituted with the namespace of the Pod currently being admitted, so the same policy correctly scopes its count to whichever namespace a Pod is being created in — `team-a`, a namespace the grading script creates fresh, anywhere.
- **`jmesPath: "items | length(@)"`** — the raw response is a `PodList`, whose Pods live under `.items`. Piping into `length(@)` collapses that array to a single number.
- **`match.resources.operations: [CREATE]`** — this was discovered to be load-bearing, not stylistic. Without it, the rule also runs on DELETE, and a namespace already at or over the 3-Pod limit can never have any of its own Pods deleted: every delete attempt re-triggers the same `apiCall`, sees the count is still over the limit, and denies the delete too. This was reproduced live — `kubectl delete ns` on an over-limit namespace hung indefinitely, with `kubectl get ns <name> -o yaml` showing a `NamespaceDeletionContentFailure` condition quoting this exact policy's own denial message, until the `ClusterPolicy` itself was removed. Scoping to `CREATE` means the quota governs admission only, and a namespace can always be cleaned up normally.
- **`exclude` for `kube-system`/`kyverno`/`local-path-storage`** — without this, a stock `kind` cluster's `kube-system` namespace (already running well over 3 system Pods) would have every future Pod reschedule blocked by this same rule, and a bug in your own policy could lock out Kyverno's own controllers. Always carve out control-plane namespaces before applying a cluster-wide Pod rule like this one.
- **`deny.conditions` referencing `{{nsPodCount}}`** — this is the part that makes the check live: the value being compared was fetched moments earlier by the `context.apiCall` above, not typed into the policy.

---

## Step 2: Apply it

```bash
kubectl apply -f policy.yaml
kubectl get clusterpolicy pod-quota-per-namespace
```

You should see `READY: True`. No extra RBAC is required for this policy — Kyverno's admission-controller ServiceAccount is already bound to the built-in `view` ClusterRole by the stock install, which grants `list`/`get` on Pods (and almost everything else read-only) cluster-wide.

---

## Step 3: Prove it against the pre-seeded namespace and a fresh one

`team-a` already has 2 Pods running (seeded by this lab's bootstrap) before your policy exists:

```bash
kubectl run seed-3 -n team-a --image=nginx --restart=Never
# pod/seed-3 created            -- count was 2, 2 < 3, admitted

kubectl run seed-4 -n team-a --image=nginx --restart=Never
# Error from server: admission webhook "validate.kyverno.svc-fail" denied the request:
# pod-quota-per-namespace:
#   limit-pods-per-namespace: Namespace "team-a" already has 3 Pod(s); the limit is 3 per namespace.
```

A brand-new namespace, with the exact same policy in place, starts at 0 and behaves independently:

```bash
kubectl create ns team-b
kubectl run b-1 -n team-b --image=nginx --restart=Never   # created
kubectl run b-2 -n team-b --image=nginx --restart=Never   # created
kubectl run b-3 -n team-b --image=nginx --restart=Never   # created
kubectl run b-4 -n team-b --image=nginx --restart=Never
# Error from server: ... Namespace "team-b" already has 3 Pod(s); the limit is 3 per namespace.
```

If your policy only ever hardcodes a threshold without actually reading `nsPodCount` from the `apiCall`, or scopes the count to the wrong namespace, one of these two scenarios will disagree with what's expected — `team-a` starting at 2 and a fresh namespace starting at 0 are deliberately different starting points, so a policy that isn't genuinely counting live, per-namespace data will fail at least one of them.

Clean up your scratch Pods and namespace when you're done (`kubectl delete pod seed-3 -n team-a --ignore-not-found; kubectl delete ns team-b --ignore-not-found`); the grading script creates and cleans up its own test Pods and namespaces independently.
