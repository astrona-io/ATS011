# Solution Guide: CEL Validation

This guide replaces a shape-matching `validate.pattern` with a `validate.cel` expression that asserts something a pattern cannot: that *every* container in the Pod sets a memory limit.

---

## Step 1: Understand what the expression has to say

A pattern describes what the resource looks like. A CEL expression states what must be **true** about it, returning a boolean. The requirement — "every container sets `resources.limits.memory`" — maps onto the `all()` macro:

```
object.spec.containers.all(c, <predicate about container c>)
```

The predicate is where the care goes. The obvious version is wrong:

```
c.resources.limits['memory'] != ''
```

On a Pod with no `resources` block, `c.resources` does not exist, and CEL raises an evaluation error rather than returning null. Under `Enforce` that error blocks the request — so the Pod *is* rejected, but by a failure of your expression rather than by your rule, and with a message you never wrote.

Guard the whole chain, relying on `&&` short-circuiting left to right:

```
has(c.resources) && has(c.resources.limits) && 'memory' in c.resources.limits
```

Each link is only evaluated once the previous one has confirmed its parent exists. Skipping the first `has(c.resources)` and starting at `has(c.resources.limits)` errors on exactly the resources you were trying to handle.

---

## Step 2: Write the policy

Create `policy.yaml`:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-memory-limits
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: check-memory-limits
      match:
        any:
          - resources:
              kinds:
                - Pod
              operations:
                - CREATE
                - UPDATE
      validate:
        cel:
          variables:
            - name: containers
              expression: "object.spec.containers"
          expressions:
            - expression: "variables.containers.all(c, has(c.resources) && has(c.resources.limits) && 'memory' in c.resources.limits)"
              message: "Every container must set spec.containers[].resources.limits.memory."
```

Everything outside `validate` is the ordinary `ClusterPolicy` you have written since Section 010 — `match`, `validationFailureAction`, `background`. Only the innards of `validate` changed.

The `operations: [CREATE, UPDATE]` restriction is not optional here, and it is the requirement most people miss. Without it the rule is also consulted on `DELETE`, where `object` is null — so `object.spec.containers` fails to evaluate, the error denies the request, and **Pods become undeletable cluster-wide**. `has()` guards do not help: the `variables` entry dereferences `object.spec` before any predicate runs. Scoping the operations is the fix.

The `variables` block is optional here with a single expression, but it is the habit worth forming: naming `object.spec.containers` once means a second or third check can reuse it instead of repeating the path.

---

## Step 3: Apply it

```bash
kubectl apply -f policy.yaml
# clusterpolicy.kyverno.io/require-memory-limits created

kubectl get clusterpolicy require-memory-limits
# NAME                    ADMISSION   BACKGROUND   READY   AGE   MESSAGE
# require-memory-limits   true        false        True    10s   Ready
```

(The `kyverno.io/v1 ClusterPolicy is deprecated` warning is expected and safe to ignore.)

---

## Step 4: Prove it with a two-container Pod

A single-container test would pass even against an expression that only ever looks at `containers[0]`. Test with two, where only the first complies:

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata: {name: half-limited}
spec:
  containers:
    - name: app
      image: nginx
      resources: {limits: {memory: "64Mi"}}
    - name: sidecar
      image: busybox
      command: ["sleep","3600"]
EOF
# Error from server: error when creating "STDIN": admission webhook
# "validate.kyverno.svc-fail" denied the request:
#
# resource Pod/default/half-limited was blocked due to the following policies
#
# require-memory-limits:
#   check-memory-limits: Every container must set spec.containers[].resources.limits.memory.
```

The message is yours, which is the thing to check. Now give the sidecar a limit:

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata: {name: fully-limited}
spec:
  containers:
    - name: app
      image: nginx
      resources: {limits: {memory: "64Mi"}}
    - name: sidecar
      image: busybox
      command: ["sleep","3600"]
      resources: {limits: {memory: "32Mi"}}
EOF
# pod/fully-limited created
```

---

## Step 5: See the failure mode you avoided

Worth doing once, so you recognise it later. Temporarily swap the expression for the unguarded version and submit a Pod with no `resources` block at all:

```bash
kubectl run noguard --image=nginx --restart=Never
# Error from server: admission webhook "validate.kyverno.svc-fail" denied the request:
#
# resource Pod/default/noguard was blocked due to the following policies
#
# no-has-guard:
#   check: 'expression ''object.spec.containers.all(c, c.resources.limits[''memory''] != '''')''
#     resulted in error: no such key: limits'
```

`resulted in error: no such key: limits` — the expression failed to evaluate and the rule fell closed. From the outside this is indistinguishable from a working policy as long as every resource you test happens to be non-compliant. That is exactly why the grading script checks for it specifically.

---

## Step 6: Grade yourself

```bash
astrona submit -c sections/section-110/module-01/labs/lab-01
```

Clean up your scratch Pods when done (`kubectl delete pod half-limited fully-limited --ignore-not-found`); the grading script creates and cleans up its own in a dedicated namespace.
