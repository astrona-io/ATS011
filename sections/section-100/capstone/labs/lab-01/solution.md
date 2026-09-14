# Solution Guide: Cleanup Policies Capstone

One `ClusterCleanupPolicy` plus one RBAC grant. The interesting part is the split: everything expressible as a selector goes in `match`, and the annotation exemption — which no selector can express — goes in `conditions`.

---

## Step 1: Grant delete permission on ConfigMaps

The cleanup controller's permissions are per-kind. The Pod grant from the module lab does nothing for ConfigMaps; you need a new rule.

Create `cleanup-rbac.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kyverno:cleanup-configmaps
  labels:
    rbac.kyverno.io/aggregate-to-cleanup-controller: "true"
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "watch", "delete"]
```

```bash
kubectl apply -f cleanup-rbac.yaml
# clusterrole.rbac.authorization.k8s.io/kyverno:cleanup-configmaps created
```

Confirm the aggregation actually landed before you go further — this is faster than discovering it from a rejected policy:

```bash
kubectl auth can-i delete configmaps \
  --as=system:serviceaccount:kyverno:kyverno-cleanup-controller
# yes
```

If that prints `no`, give aggregation a few more seconds and check the label spelling: `rbac.kyverno.io/aggregate-to-cleanup-controller: "true"`.

---

## Step 2: Decide what goes where

The task has three narrowing criteria. Two of them are selectors and one is not:

| Criterion | Expressible as a selector? | Goes in |
| :--- | :--- | :--- |
| namespace is `capstone-cleanup` | yes — `match.resources.namespaces` | `match` |
| label `lifecycle: ephemeral` | yes — `match.resources.selector` | `match` |
| annotation `example.com/retain` is not `"true"` | **no** — annotations are not selectable | `conditions` |

That last row is the whole point of the capstone. Kubernetes label selectors operate on labels only; annotations are opaque metadata the API server will not filter on. So the exemption has to be evaluated per-resource by Kyverno, after the candidates come back — which is exactly what `conditions` is for.

Putting the first two in `match` is not just style. `match` becomes the selector used when listing candidates from the API server, so a tight `match` means each tick lists a handful of ConfigMaps in one namespace instead of every ConfigMap in the cluster.

---

## Step 3: Write the policy

Create `cleanup-policy.yaml`:

```yaml
apiVersion: kyverno.io/v2
kind: ClusterCleanupPolicy
metadata:
  name: sweep-ephemeral-configmaps
spec:
  match:
    any:
      - resources:
          kinds:
            - ConfigMap
          namespaces:
            - capstone-cleanup
          selector:
            matchLabels:
              lifecycle: ephemeral
  conditions:
    all:
      - key: "{{ target.metadata.annotations.\"example.com/retain\" || '' }}"
        operator: NotEquals
        value: "true"
  schedule: "* * * * *"
```

```bash
kubectl apply -f cleanup-policy.yaml
# clustercleanuppolicy.kyverno.io/sweep-ephemeral-configmaps created
```

Decoding the condition key piece by piece:

* **`target`** — not `request.object`. There is no admission request during a sweep; the candidate resource under evaluation is exposed as `target`.
* **`."example.com/retain"`** — the annotation key contains a `/`, which JMESPath would otherwise read as syntax, so it is quoted. (Compare Section 080, where the *same* kind of key needed `~1` escaping in a JSON Pointer instead. Different language, different escape.)
* **`|| ''`** — the fallback that makes this safe. A ConfigMap with no `annotations` block at all — `cm-sweep` and `cm-unlabelled` in the grading set — would otherwise leave the variable unresolved, and an unresolved variable is an evaluation error, not an empty string.
* **`NotEquals "true"`** — "delete it unless it is explicitly retained." Written this way, anything that is not literally `"true"` (absent, empty, `"false"`, `"yes"`) is swept. That is the safe polarity for an exemption: a typo in the annotation value fails toward deletion of scratch data rather than toward silently retaining everything forever.

---

## Step 4: Prove all four outcomes

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: cm-sweep
  namespace: capstone-cleanup
  labels:
    lifecycle: ephemeral
data:
  note: "must be deleted"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: cm-retained
  namespace: capstone-cleanup
  labels:
    lifecycle: ephemeral
  annotations:
    example.com/retain: "true"
data:
  note: "must survive"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: cm-unlabelled
  namespace: capstone-cleanup
data:
  note: "must survive"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: cm-other-ns
  namespace: capstone-keep
  labels:
    lifecycle: ephemeral
data:
  note: "must survive"
EOF
```

Wait for the next minute boundary, then:

```bash
kubectl get cm -n capstone-cleanup --no-headers | grep -v kube-root-ca
# cm-retained     1   85s
# cm-unlabelled   1   85s

kubectl get cm -n capstone-keep --no-headers | grep -v kube-root-ca
# cm-other-ns   1   85s
```

Exactly one ConfigMap gone. Each survivor was spared by a different part of the policy: `cm-retained` by the `conditions` block, `cm-unlabelled` by the label selector, `cm-other-ns` by the namespace restriction. If more than one disappeared, the failure tells you which clause is missing.

Confirm the sweep ran rather than assuming it did:

```bash
kubectl get clustercleanuppolicy sweep-ephemeral-configmaps -o jsonpath='{.status}'
# {"lastExecutionTime":"..."}
```

A `lastExecutionTime` that is minutes old means the schedule is not what you think it is.

---

## Step 5: Grade yourself

```bash
astrona submit -c sections/section-100/capstone/labs/lab-01
```

The grading script seeds its own copies of all four ConfigMaps and waits for a sweep, so it may take a couple of minutes to return.
