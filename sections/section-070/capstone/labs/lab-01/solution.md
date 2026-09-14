# Solution Guide: Variables & API Calls Capstone

One `ClusterPolicy`, one rule, two `context` entries: an `apiCall` for the live quota decision, and a `variable` for the named rejection message.

---

## Step 1: Write the policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: pod-quota-with-named-rejection
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: limit-pods-per-namespace-named
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
        - name: podName
          variable:
            jmesPath: "request.object.metadata.name"
      validate:
        message: >-
          Pod "{{podName}}" cannot be admitted into namespace
          "{{request.namespace}}": it already has {{nsPodCount}}
          Pod(s), and the limit is 3 per namespace.
        deny:
          conditions:
            any:
              - key: "{{nsPodCount}}"
                operator: GreaterThanOrEquals
                value: 3
```

Two distinct mechanisms are doing two distinct jobs here:

- **`nsPodCount` (`apiCall`)** reaches *outside* the request, to the live Kubernetes API, to fetch data Kyverno doesn't already have — this is what actually decides admit vs. reject.
- **`podName` (`variable`)** runs a JMESPath expression against data Kyverno already has *in hand* — no network call at all — just to give a long expression (`request.object.metadata.name`) a short name, used to make the rejection message name the actual Pod.
- **`match.resources.operations: [CREATE]`** — this is load-bearing, not stylistic, and was found by testing rather than assumed. Without it, the rule also evaluates on DELETE, and a namespace already at or over the 3-Pod limit can never have any of its own Pods deleted: every delete attempt re-triggers the same `apiCall`, sees the count is still over the limit, and denies the delete too. This was reproduced live — `kubectl delete ns` on an over-limit namespace hung indefinitely, with the namespace's own status showing a `NamespaceDeletionContentFailure` condition quoting this exact policy's denial message, until the `ClusterPolicy` itself was removed. Scoping to `CREATE` means the quota only ever governs admission, never deletion.

You could have written `{{ request.object.metadata.name }}` directly inline in the `message` instead of introducing `podName` — for a single use they're equivalent. The `variable` context entry is included here because the capstone specifically exercises it as its own mechanism, and because naming a value you reference is good habit once a rule grows past one or two uses of the same expression.

---

## Step 2: Apply it

```bash
kubectl apply -f policy.yaml
kubectl get clusterpolicy pod-quota-with-named-rejection
```

`READY: True`, and — same as the module lab — no extra RBAC is required, since Kyverno's admission-controller is already bound to the built-in `view` ClusterRole, which covers reading Pods cluster-wide.

---

## Step 3: Prove both mechanisms are load-bearing

`cap-a` already has 2 Pods running (seeded by this lab's bootstrap):

```bash
kubectl run capstone-third -n cap-a --image=nginx --restart=Never
# pod/capstone-third created         -- count was 2, admitted

kubectl run capstone-fourth -n cap-a --image=nginx --restart=Never
# Error from server: admission webhook "validate.kyverno.svc-fail" denied the request:
#
# resource Pod/cap-a/capstone-fourth was blocked due to the following policies
#
# pod-quota-with-named-rejection:
#   limit-pods-per-namespace-named: 'Pod "capstone-fourth" cannot be admitted into
#     namespace "cap-a": it already has 3 Pod(s), and the limit is 3 per namespace.'
```

Notice the message literally contains `"capstone-fourth"` — the actual name of the Pod that was rejected, pulled live from `podName`, not a generic sentence. A brand-new namespace confirms the `apiCall` side independently:

```bash
kubectl create ns cap-b
kubectl run cb-1 -n cap-b --image=nginx --restart=Never   # created
kubectl run cb-2 -n cap-b --image=nginx --restart=Never   # created
kubectl run cb-3 -n cap-b --image=nginx --restart=Never   # created
kubectl run cap-b-limit-breaker -n cap-b --image=nginx --restart=Never
# Error from server: ... Pod "cap-b-limit-breaker" cannot be admitted into namespace
# "cap-b": it already has 3 Pod(s), and the limit is 3 per namespace.
```

Both the admit/reject decision (driven by `nsPodCount`, correctly scoped per namespace) and the message content (driven by `podName`, correctly naming whichever Pod triggered the rejection) hold across two independently-seeded namespaces — proof neither mechanism is a hardcoded stand-in for the other.

Clean up your scratch Pods and namespace when you're done (`kubectl delete pod capstone-third -n cap-a --ignore-not-found; kubectl delete ns cap-b --ignore-not-found`); the grading script creates and cleans up its own test resources independently.
