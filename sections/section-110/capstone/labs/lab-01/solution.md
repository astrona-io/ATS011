# Solution Guide: CEL Capstone

One `ValidatingPolicy`, with the task's five requirements landing in five different fields. Most of the difficulty is deciding *which* field each requirement belongs in — the expressions themselves are short.

---

## Step 1: Map each requirement to a field

| Requirement | Field |
| :--- | :--- |
| Match Pods on CREATE and UPDATE | `spec.matchConstraints.resourceRules` |
| Exempt the `cel-exempt` namespace | `spec.matchConditions` |
| Every container sets a memory limit | `spec.validations[]` |
| Every container image has an explicit non-`latest` tag | `spec.validations[]` |
| Deny on failure | `spec.validationActions` |
| Also produce a native `ValidatingAdmissionPolicy` | `spec.autogen.validatingAdmissionPolicy.enabled` |

The third row of the task — the namespace exemption — is the one with a real decision behind it. You *could* fold `object.metadata.namespace != 'cel-exempt'` into each validation expression and get the same admitted/rejected outcomes. But that says "a Pod in `cel-exempt` is compliant," which is not what you mean. `matchConditions` says "this policy does not apply there," which is what you mean, and it keeps the compliance expressions about compliance. The grading script checks that `spec.matchConditions` is actually populated, not just that the behaviour comes out right.

---

## Step 2: Write the policy

Create `vpol.yaml`:

```yaml
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: pod-baseline
spec:
  validationActions:
    - Deny
  autogen:
    validatingAdmissionPolicy:
      enabled: true
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  matchConditions:
    - name: skip-exempt-namespace
      expression: "request.namespace != 'cel-exempt'"
  variables:
    - name: containers
      expression: "object.spec.containers"
  validations:
    - expression: "variables.containers.all(c, has(c.resources) && has(c.resources.limits) && 'memory' in c.resources.limits)"
      message: "Every container must set resources.limits.memory."
    - expression: "variables.containers.all(c, c.image.contains(':') && !c.image.endsWith(':latest'))"
      message: "Every container image must use an explicit tag other than latest."
```

Field by field:

* **`resources: ["pods"]`** — lowercase plural API resource name, the same spelling RBAC uses. Writing `Pod` here is the single most common first-attempt error; that is `ClusterPolicy` `match` vocabulary.
* **`operations: ["CREATE", "UPDATE"]`** — without `UPDATE`, an admitted compliant Pod could be edited into a non-compliant one and nothing would object. Note that the explicit operations list also means `DELETE` is never matched, so the DELETE-lockout trap from the module lab cannot occur here.
* **`request.namespace`** rather than `object.metadata.namespace` — the admission request always carries the target namespace, whether or not the submitted YAML happened to spell it out.
* **`validationActions: [Deny]`** — a list, and `Deny` rather than `Enforce`. `Enforce` belongs to `ClusterPolicy`. (`Deny` and `Warn` may not be combined; `[Audit, Warn]` is the usual pre-rollout posture.)
* **Two separate `validations` entries, not one `&&`** — each carries its own `message`, so a rejection tells the developer which requirement they missed rather than reciting both.
* **`c.image.contains(':')`** — this is what catches a bare `nginx`. Checking only `!c.image.endsWith(':latest')` passes an untagged image, which Kubernetes then resolves to `:latest` anyway. Requiring a `:` first means "you must have said which version you meant."

---

## Step 3: Apply and confirm the generated VAP

```bash
kubectl apply -f vpol.yaml
# validatingpolicy.policies.kyverno.io/pod-baseline created

kubectl get validatingpolicy
# NAME           AGE   READY
# pod-baseline   10s   true
```

No deprecation warning this time — this is the current API, not the classic one.

Now confirm Kyverno compiled it into a native Kubernetes policy object:

```bash
kubectl get validatingadmissionpolicy
# NAME                VALIDATIONS   PARAMKIND   AGE
# vpol-pod-baseline   2             <unset>     15s

kubectl get validatingadmissionpolicybinding
# NAME                        POLICYNAME          PARAMREF   AGE
# vpol-pod-baseline-binding   vpol-pod-baseline   <unset>    15s
```

Both objects matter. The `ValidatingAdmissionPolicy` holds the translated expressions; the binding is what activates it. A VAP with no binding enforces nothing at all.

---

## Step 4: Prove all five outcomes

```bash
kubectl create ns cel-demo

# 1. No memory limit -> rejected
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata: {name: no-limit, namespace: cel-demo}
spec:
  containers: [{name: app, image: "nginx:1.27"}]
EOF

# 2. :latest tag -> rejected
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata: {name: latest-tag, namespace: cel-demo}
spec:
  containers:
    - name: app
      image: "nginx:latest"
      resources: {limits: {memory: "64Mi"}}
EOF

# 3. No tag at all -> rejected (resolves to :latest)
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata: {name: no-tag, namespace: cel-demo}
spec:
  containers:
    - name: app
      image: "nginx"
      resources: {limits: {memory: "64Mi"}}
EOF

# 4. Fully compliant -> admitted
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata: {name: compliant, namespace: cel-demo}
spec:
  containers:
    - name: app
      image: "nginx:1.27"
      resources: {limits: {memory: "64Mi"}}
EOF
# pod/compliant created

# 5. Non-compliant, but in the exempt namespace -> admitted
kubectl run exempt-pod -n cel-exempt --image=nginx --restart=Never
# pod/exempt-pod created
```

Look closely at how the rejections are phrased:

```
The pods "no-limit" is invalid: : ValidatingAdmissionPolicy 'vpol-pod-baseline'
with binding 'vpol-pod-baseline-binding' denied request:
Every container must set resources.limits.memory.
```

There is no `admission webhook ... denied the request` in that message. The API server enforced its own policy object; Kyverno wrote the VAP and stepped out of the request path entirely. That is the architectural payoff of writing the policy in the API server's own language — and the reason it cannot fail because a webhook is unreachable.

---

## Step 5: Grade yourself

```bash
astrona submit -c sections/section-110/capstone/labs/lab-01
```

Clean up your scratch namespace when done:

```bash
kubectl delete ns cel-demo --ignore-not-found
kubectl delete pod exempt-pod -n cel-exempt --ignore-not-found
```
