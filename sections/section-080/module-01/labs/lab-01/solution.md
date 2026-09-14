# Solution Guide: JSON Patches

This guide builds a `ClusterPolicy` with a single `mutate.patchesJson6902` rule that appends an environment variable to container index `0` of every Pod, using the RFC 6902 `add` operation targeting `/spec/containers/0/env/-`.

---

## Step 1: Write the policy

Create `policy.yaml`:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: inject-env-json-patch
spec:
  rules:
    - name: add-env-var
      match:
        any:
          - resources:
              kinds:
                - Pod
      mutate:
        patchesJson6902: |-
          - op: add
            path: /spec/containers/0/env/-
            value:
              name: INJECTED_BY_POLICY
              value: "true"
```

The trailing `-` in `/spec/containers/0/env/-` is RFC 6902's "append to the end of this array" index. `op: add` targeting that path is the JSON Patch idiom for "add one more element to this list," as opposed to `replace`, which would require you to already know an exact index to overwrite.

---

## Step 2: Apply it

```bash
kubectl apply -f policy.yaml
kubectl get clusterpolicy inject-env-json-patch
```

You should see `READY: True`. (You will also see the familiar `kyverno.io/v1 ClusterPolicy is deprecated` warning — expected and safe to ignore.)

---

## Step 3: Prove it against both an env-bearing and an env-less Pod

```bash
# A Pod whose first container already declares env entries
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: has-env
spec:
  containers:
    - name: app
      image: nginx
      env:
        - name: EXISTING
          value: "one"
EOF
kubectl get pod has-env -o jsonpath='{.spec.containers[0].env}'
# [{"name":"EXISTING","value":"one"},{"name":"INJECTED_BY_POLICY","value":"true"}]

# A Pod whose first container has no env array at all
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: no-env
spec:
  containers:
    - name: app
      image: nginx
EOF
kubectl get pod no-env -o jsonpath='{.spec.containers[0].env}'
# [{"name":"INJECTED_BY_POLICY","value":"true"}]
```

Both Pods come out correctly patched — `EXISTING` survives untouched on `has-env`, and `env` is created from scratch on `no-env`. This was verified directly while building this course: RFC 6902's `add` operation is documented to accept `/array/-` even when the parent key is entirely absent from the object, silently creating the array with your value as its only element, rather than erroring the way you might expect an operation against a genuinely missing path to behave.

Clean up your scratch Pods when done (`kubectl delete pod has-env no-env --ignore-not-found`); the grading script creates and cleans up its own test Pods independently in a dedicated namespace.
