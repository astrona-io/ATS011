# Solution Guide: Mutation Rules

This guide builds a `ClusterPolicy` with one `mutate` rule that patches every incoming Pod using `patchStrategicMerge`.

---

## Step 1: Write the policy

Create `policy.yaml`:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: default-pod-baseline
spec:
  rules:
    - name: inject-pod-defaults
      match:
        any:
          - resources:
              kinds:
                - Pod
      mutate:
        patchStrategicMerge:
          metadata:
            labels:
              managed-by: platform
          spec:
            containers:
              - (name): "*"
                imagePullPolicy: IfNotPresent
```

Two things about this shape are load-bearing, not stylistic:

- `metadata.labels.managed-by: platform` is a plain scalar merge — Kyverno strategic-merges this fragment into whatever labels the incoming Pod already has, adding the key if it's missing and **overwriting** it if it's already present with a different value. There's no "only if absent" mode for a scalar field in a strategic-merge patch: the patch's value always wins.
- `spec.containers` uses the `(name): "*"` anchor. Without it, a plain list entry (`- imagePullPolicy: IfNotPresent` with no `name`) is matched by *position* the same way `validate.pattern` is — it would try to merge into container index 0 by a merge key of `""`, find no match, and *insert* a malformed container missing its own `name` field, which the API server then rejects outright as an invalid Pod. The anchor tells Kyverno "apply this fragment to every element whose `name` matches this wildcard" — which is every container, regardless of how many the Pod has.

---

## Step 2: Apply it

```bash
kubectl apply -f policy.yaml
kubectl get clusterpolicy default-pod-baseline
```

You should see `READY: True` (plus the usual `kyverno.io/v1 ClusterPolicy is deprecated` warning — expected, ignore it).

---

## Step 3: Prove it against a plain Pod, a multi-container Pod, and a conflicting Pod

```bash
kubectl run plain-pod --image=nginx --restart=Never
kubectl get pod plain-pod -o jsonpath='{.metadata.labels}'
# {"managed-by":"platform","run":"plain-pod"}
kubectl get pod plain-pod -o jsonpath='{.spec.containers[0].imagePullPolicy}'
# IfNotPresent
```

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: multi-container-pod
spec:
  containers:
    - name: app
      image: nginx
    - name: sidecar
      image: busybox
      command: ["sleep", "3600"]
EOF
kubectl get pod multi-container-pod -o jsonpath='{range .spec.containers[*]}{.name}={.imagePullPolicy}{"\n"}{end}'
# app=IfNotPresent
# sidecar=IfNotPresent
```

Both containers were patched, not just the first — proof the anchor is doing real per-element work.

Now the interesting case: a Pod that *already* sets a conflicting value for both fields.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: conflict-pod
  labels:
    managed-by: team-x
spec:
  containers:
    - name: app
      image: nginx
      imagePullPolicy: Always
EOF
kubectl get pod conflict-pod -o jsonpath='{.metadata.labels}'
# {"managed-by":"platform"}
kubectl get pod conflict-pod -o jsonpath='{.spec.containers[0].imagePullPolicy}'
# IfNotPresent
```

Both fields were **overwritten** to the policy's value, even though the incoming Pod explicitly set something else. This was verified live while building this lab, not assumed: `patchStrategicMerge` is not an "only fill in if absent" default — it always applies your fragment, and for a scalar field that means the policy's value replaces whatever the requester sent. If you need "set this only if the field is missing," you need a `precondition` checking whether the field already exists (Section 020 covers preconditions) — a plain `patchStrategicMerge` alone cannot express that.

Clean up your scratch Pods when you're done (`kubectl delete pod plain-pod multi-container-pod conflict-pod --ignore-not-found`); the grading script creates and cleans up its own test Pods independently in a dedicated namespace.
