# Solution Guide: Pattern-Based Validation

This guide builds a `ClusterPolicy` with two rules: one plain `pattern` check for the label, and one `foreach` check that covers every container regardless of how many a Pod has.

---

## Step 1: Write the policy

Create `policy.yaml`:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-team-and-limits
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: check-team-label
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "A team label is required on every Pod."
        pattern:
          metadata:
            labels:
              team: "?*"

    - name: check-container-limits
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "Every container must set CPU and memory limits."
        foreach:
          - list: "request.object.spec.containers"
            pattern:
              resources:
                limits:
                  memory: "?*"
                  cpu: "?*"
```

The first rule uses a plain `pattern` because it checks one scalar field. The second rule uses `foreach` deliberately — a plain `pattern` against `spec.containers` only checks the container at list position 0, so a two-container Pod with a broken second container would slip through undetected.

---

## Step 2: Apply it

```bash
kubectl apply -f policy.yaml
kubectl get clusterpolicy require-team-and-limits
```

You should see `READY: True`. (You will also see a deprecation warning about `kyverno.io/v1` pointing you toward the newer CEL-based policy types — that is expected and safe to ignore for this lab; Section 110 covers CEL.)

---

## Step 3: Prove it against both a bad and a good Pod

```bash
kubectl run bad-pod --image=nginx --restart=Never
# Error from server: admission webhook "validate.kyverno.svc-fail" denied the request: ...
# check-team-label failed at path /metadata/labels/team/

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: good-pod
  labels:
    team: platform
spec:
  containers:
    - name: app
      image: nginx
      resources:
        limits: { cpu: "250m", memory: "128Mi" }
    - name: sidecar
      image: busybox
      command: ["sleep", "3600"]
      resources:
        limits: { cpu: "100m", memory: "64Mi" }
EOF
# pod/good-pod created
```

If the second container in `good-pod` were missing its `resources.limits` block, the `foreach` rule would reject the whole Pod at `check-container-limits`, naming that rule specifically — proof the loop is actually reaching every element, not just the first.

Clean up your scratch Pods when you're done (`kubectl delete pod bad-pod good-pod --ignore-not-found`); the grading script creates and cleans up its own test Pods independently in a dedicated namespace.
