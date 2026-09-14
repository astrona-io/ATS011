# Solution Guide: JSON Patches Capstone

One `ClusterPolicy`, two rules — an unconditional `add` for the required annotation, and a `remove` guarded by a `precondition` for the disallowed one.

---

## Step 1: Write the policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: annotation-baseline
spec:
  rules:
    - name: add-required-annotation
      match:
        any:
          - resources:
              kinds:
                - Pod
      mutate:
        patchesJson6902: |-
          - op: add
            path: /metadata/annotations/policy.example.com~1reviewed
            value: "true"

    - name: remove-disallowed-annotation-if-present
      match:
        any:
          - resources:
              kinds:
                - Pod
      preconditions:
        all:
          - key: "{{ request.object.metadata.annotations.\"legacy/unmanaged-scanner\" || '' }}"
            operator: NotEquals
            value: ""
      mutate:
        patchesJson6902: |-
          - op: remove
            path: /metadata/annotations/legacy~1unmanaged-scanner
```

```bash
kubectl apply -f policy.yaml
kubectl get clusterpolicy annotation-baseline
```

---

## Step 2: Walk through why each piece is shaped this way

- **`~1` instead of `/`** — RFC 6902 JSON Pointer syntax reserves `/` as a path separator, so a literal `/` inside a key name (as in `policy.example.com/reviewed` or `legacy/unmanaged-scanner`) must be escaped as `~1`. This is a JSON Patch mechanic, not a Kyverno one, and it trips up almost everyone the first time they target a namespaced annotation key with `patchesJson6902`.
- **`add` targeting an annotation key that may already exist** — RFC 6902's `add` operation, when the target member already exists, *replaces* its value rather than erroring. So the first rule is safe to run on every Pod unconditionally, whether or not `policy.example.com/reviewed` was already set to something else.
- **Why the second rule needs a `precondition` at all** — this was verified directly while building this course: as of Kyverno v1.19.1, a `remove` operation whose target path does not exist is applied as a silent no-op — the request is still admitted, nothing errors. That matches Kyverno's own documented intent for `remove`. But relying on that leniency alone is not the recommended pattern (Kyverno's own guidance and issue history flag this behavior as something that has been inconsistent across versions), and — critically — it is *not* how every other JSON Patch operation behaves on this exact cluster: a `replace` against a path that doesn't exist (verified separately, same cluster, same Kyverno version) rejects the entire admission request with `replace operation does not apply: doc is missing path: ... missing value`. Guarding the `remove` with an explicit `preconditions.all` check that the annotation is actually present is the portable, version-proof, "don't gamble on lenient-vs-strict op behavior" way to write this rule — and it is the only approach that would also work correctly if you swapped `remove` for `replace` later.
- **The precondition itself** — `{{ request.object.metadata.annotations."legacy/unmanaged-scanner" || '' }}` reads as "the annotation's value, or an empty string if the key or the whole `annotations` map is missing." Comparing that against `""` with `NotEquals` is Kyverno's standard idiom for "does this key exist" when the key might not even have a parent map to look inside — a raw `{{ request.object.metadata.annotations."legacy/unmanaged-scanner" }}` with no `||` fallback would itself error out during variable resolution on a Pod with no `annotations` block at all.

---

## Step 3: Prove all three scenarios by hand

```bash
# 1. Pod with the disallowed annotation and nothing else -> annotation removed, required one added
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-disallowed
  annotations:
    legacy/unmanaged-scanner: "true"
spec:
  containers:
    - name: app
      image: nginx
EOF
kubectl get pod pod-with-disallowed -o jsonpath='{.metadata.annotations}'
# {"policy.example.com/reviewed":"true", ...}  -- legacy/unmanaged-scanner is gone

# 2. Pod that never had the disallowed annotation -> admitted normally, required one still added
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pod-without-disallowed
spec:
  containers:
    - name: app
      image: nginx
EOF
# pod/pod-without-disallowed created  -- no error, no rejection

# 3. Pod with an unrelated annotation alongside the disallowed one -> unrelated one survives
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pod-mixed-annotations
  annotations:
    legacy/unmanaged-scanner: "true"
    team: platform
spec:
  containers:
    - name: app
      image: nginx
EOF
kubectl get pod pod-mixed-annotations -o jsonpath='{.metadata.annotations.team}'
# platform
```

Clean up your scratch Pods when done; the grading script creates and cleans up its own test Pods independently in a dedicated namespace.
