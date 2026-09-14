# Solution Guide: VerifyImage Rules Capstone

One `ClusterPolicy`, two rules — one `verifyImages` rule for the signature, one `foreach` validate rule for the per-container limits. The two rules are independent gates: a Pod must clear both.

---

## Step 1: Write the policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: signed-and-limited
spec:
  webhookConfiguration:
    failurePolicy: Fail
    timeoutSeconds: 30
  background: false
  rules:
    - name: check-image-signature
      match:
        any:
          - resources:
              kinds:
                - Pod
      verifyImages:
        - imageReferences:
            - 'ghcr.io/kyverno/test-verify-image*'
          failureAction: Enforce
          attestors:
            - count: 1
              entries:
                - keys:
                    publicKeys: |-
                      -----BEGIN PUBLIC KEY-----
                      MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE8nXRh950IZbRj8Ra/N9sbqOPZrfM
                      5/KAQN0/KjHcorm/J5yctVd7iEcnessRQjU917hmKO6JWVGHpDguIyakZA==
                      -----END PUBLIC KEY-----
                    rekor:
                      ignoreTlog: true
                      url: https://rekor.sigstore.dev

    - name: check-container-limits
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "Every container must set CPU and memory limits."
        failureAction: Enforce
        foreach:
          - list: "request.object.spec.containers"
            pattern:
              resources:
                limits:
                  memory: "?*"
                  cpu: "?*"
```

```bash
kubectl apply -f policy.yaml
kubectl get clusterpolicy signed-and-limited
```

---

## Step 2: Why two independent rules, not one

Kyverno evaluates every rule in a policy against a matching resource, and any single rule failing blocks the whole admission — so splitting "is it signed" and "does it declare limits" into two rules doesn't weaken enforcement, it makes the two checks orthogonal and their failure messages distinct. Trying to force both checks into a single rule isn't even possible here: `verifyImages` and `validate` are different rule mechanisms and cannot occupy the same rule entry.

---

## Step 3: Prove all four scenarios by hand

```bash
# 1. Unsigned image, no limits — rejected by the signature rule first
kubectl run bad1 --image=ghcr.io/kyverno/test-verify-image:unsigned --restart=Never
# Error ... check-image-signature: 'failed to verify image ... unsigned: ...'

# 2. Signed image, but missing limits — rejected by the validate rule
kubectl run bad2 --image=ghcr.io/kyverno/test-verify-image:signed --restart=Never
# Error ... check-container-limits: 'validation failure: ... Every container must
#   set CPU and memory limits. rule check-container-limits failed at path /resources/limits/'

# 3. Signed image, with limits — admitted
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: good1
spec:
  containers:
    - name: app
      image: ghcr.io/kyverno/test-verify-image:signed
      resources:
        limits: { cpu: "100m", memory: "64Mi" }
EOF
# pod/good1 created

# 4. Unsigned image, WITH limits — still rejected (the signature rule doesn't care about limits)
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: bad3
spec:
  containers:
    - name: app
      image: ghcr.io/kyverno/test-verify-image:unsigned
      resources:
        limits: { cpu: "100m", memory: "64Mi" }
EOF
# Error ... check-image-signature: 'failed to verify image ... unsigned: ...'
```

Scenario 4 is the one worth sitting with: adding valid `resources.limits` to a Pod does nothing for a failing signature check, because the two rules are independently evaluated and either one failing blocks the whole request. This is exactly how you'd compose real policy in production — a supply-chain gate and a resource-hygiene gate rarely have anything to do with each other, and Kyverno doesn't force you to merge their logic just because they both target `Pod`.

Clean up your scratch Pods when you're done; the grading script creates and cleans up its own test Pods independently in a dedicated namespace.
