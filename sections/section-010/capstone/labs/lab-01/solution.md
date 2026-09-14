# Solution Guide: Validation Rules Capstone

One `ClusterPolicy`, two rules — one `anyPattern` for the OR condition, one `foreach` for the per-container loop.

---

## Step 1: Write the policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: pod-baseline
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: check-ownership
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "Every Pod needs either a non-empty 'team' label or a non-empty 'owner' annotation."
        anyPattern:
          - metadata:
              labels:
                team: "?*"
          - metadata:
              annotations:
                owner: "?*"

    - name: check-container-baseline
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "Every container must set CPU/memory limits and use a pinned (non-'latest') image tag."
        foreach:
          - list: "request.object.spec.containers"
            pattern:
              image: "!*:latest"
              resources:
                limits:
                  memory: "?*"
                  cpu: "?*"
```

```bash
kubectl apply -f policy.yaml
kubectl get clusterpolicy pod-baseline
```

---

## Step 2: Walk through why each piece is shaped this way

- **`anyPattern` for ownership** — a plain `pattern` would AND its fields together, forcing *both* a label and an annotation. `anyPattern` is the only place OR logic lives inside `validate`; it passes the moment either branch matches.
- **`foreach` for the container loop** — a plain `pattern` against `spec.containers` checks list position 0 only. With `foreach`, every container is checked against the nested `pattern` independently, and the rule fails at the first container that doesn't satisfy it.
- **`image: "!*:latest"`** — the `!` operator combined with the `*` wildcard reads as "does not match this shape." `nginx:latest` matches `*:latest` so it's rejected; `nginx:1.25` doesn't match the wildcard at all, so it passes.
- **Only `limits`, not `requests`, is checked** — Kubernetes' own API defaulting fills in a container's `resources.requests` from `resources.limits` when `requests` is omitted, *before* Kyverno ever evaluates the object. A rule requiring `resources.requests` in addition to `limits` would never actually observe a "requests missing" case once limits is set — the field will always already be populated by the time an admission webhook sees it. This is why real-world Kyverno policies almost always gate on `limits`, and why this policy doesn't bother declaring a separate `requests` check.

---

## Step 3: Prove all five scenarios by hand

```bash
# 1. Bare Pod — no label/annotation, no limits, :latest tag — rejected
kubectl run bad --image=nginx:latest --restart=Never
# Error ... check-ownership ... AND/OR check-container-baseline failed

# 2. Owner annotation only, fully compliant containers — admitted
kubectl run good-a --image=nginx:1.25 --restart=Never \
  --annotations=owner=platform-team \
  --overrides='{"spec":{"containers":[{"name":"good-a","image":"nginx:1.25","resources":{"limits":{"cpu":"250m","memory":"128Mi"}}}]}}'
# pod/good-a created

# 3. Team label present, but the image is :latest — rejected
# 4. Team label present, but a container has no limits — rejected
# 5. Team label present, every container pinned + limited — admitted
```

The grading script exercises all five cases directly against the API server, independent of how you split your rules across policies.
