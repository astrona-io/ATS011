# Solution Guide: Preconditions

This guide builds a `ClusterPolicy` with a single rule: a `pattern` check for the `team` label, gated by a `preconditions.all` block that skips the check entirely when the Pod carries `tier: exempt`.

---

## Step 1: Write the policy

Create `policy.yaml`:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-team-label-with-exemption
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: check-team-label-unless-exempt
      match:
        any:
          - resources:
              kinds:
                - Pod
      preconditions:
        all:
          - key: "{{ request.object.metadata.labels.tier || '' }}"
            operator: NotEquals
            value: "exempt"
      validate:
        message: "A team label is required on every Pod, unless it carries tier: exempt."
        pattern:
          metadata:
            labels:
              team: "?*"
```

The `match` block is unchanged from Section 010 — it still just says "look at every Pod." The exemption lives entirely in `preconditions`: `key` reads the incoming Pod's own `metadata.labels.tier`, and `|| ''` supplies an empty-string default so the expression doesn't error out on a Pod that has no `tier` label at all. `operator: NotEquals` against `value: "exempt"` means *this precondition is true (and the rule proceeds to validate) for every Pod except one explicitly labeled `tier: exempt`*.

---

## Step 2: Apply it

```bash
kubectl apply -f policy.yaml
kubectl get clusterpolicy require-team-label-with-exemption
```

You should see `READY: True`. (The `kyverno.io/v1 ClusterPolicy is deprecated` warning is expected — ignore it.)

---

## Step 3: Prove all three outcomes by hand

```bash
# 1. No team label, no exemption -> rejected
kubectl run bad-pod --image=nginx --restart=Never
# Error from server: admission webhook "validate.kyverno.svc-fail" denied the request:
# check-team-label-unless-exempt failed at path /metadata/labels/team/

# 2. No team label, BUT tier: exempt -> admitted (the precondition skipped the check)
kubectl run exempt-pod --image=nginx --restart=Never --labels=tier=exempt
# pod/exempt-pod created

# 3. team label present, no exemption -> still admitted (the rule isn't a blanket blocker)
kubectl run good-pod --image=nginx --restart=Never --labels=team=platform
# pod/good-pod created
```

Case 2 is the one that actually proves the precondition works: the Pod has no `team` label, so if the precondition weren't gating the rule at all, `validate.pattern` would reject it exactly like case 1. Instead Kyverno evaluates `preconditions.all` first, finds `tier` equals `exempt`, sees the `NotEquals` condition is false, and never runs `validate` for this resource at all — the rule is skipped, not merely satisfied.

> [!NOTE]
> This particular exemption — skip the rule when a label carries an exact value — could also have been written as `exclude.any[].resources.selector.matchExpressions: [{key: tier, operator: NotIn, values: [exempt]}]`, without touching `preconditions` at all. `match`/`exclude` selectors do support label equality and set membership. This lab still asks you to write it as a precondition on purpose: the mechanic (a `key`/`operator`/`value` condition evaluated against the live resource) is the one you need fluency with for cases `match`/`exclude` genuinely cannot reach — Part 2 of this module walks through exactly where that boundary is and why.

Clean up your scratch Pods when you're done (`kubectl delete pod bad-pod exempt-pod good-pod --ignore-not-found`); the grading script creates and cleans up its own test Pods independently in a dedicated namespace.
