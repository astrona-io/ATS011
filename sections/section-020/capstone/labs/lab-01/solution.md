# Solution Guide: Preconditions Capstone

One `ClusterPolicy`, one rule, with a `preconditions.all` block that ANDs two independent conditions together.

---

## Step 1: Write the policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-team-label-on-create
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: check-team-label-create-only
      match:
        any:
          - resources:
              kinds:
                - Pod
      preconditions:
        all:
          - key: "{{ request.operation }}"
            operator: Equals
            value: "CREATE"
          - key: "{{ request.namespace }}"
            operator: NotEquals
            value: "trusted-automation"
      validate:
        message: "New Pods must carry a non-empty team label (namespace 'trusted-automation' is exempt)."
        pattern:
          metadata:
            labels:
              team: "?*"
```

```bash
kubectl apply -f policy.yaml
kubectl get clusterpolicy require-team-label-on-create
```

---

## Step 2: Walk through why each piece is shaped this way

- **`preconditions.all` is an AND** — both entries must evaluate `true` before Kyverno even looks at `validate.pattern`. If either one is `false`, the entire rule is skipped for that admission request, and the Pod is admitted regardless of whether it has a `team` label.
- **`{{ request.operation }}` Equals `"CREATE"`** — `request.operation` is the admission verb Kubernetes sends with every request (`CREATE`, `UPDATE`, `DELETE`, `CONNECT`). This is not something `match`/`exclude` can express at all: `match` filters by what a resource *is* (kind, namespace, labels, name), never by what *verb* is being performed against it. Scoping a rule to `CREATE` only is a precondition-only capability.
- **`{{ request.namespace }}` NotEquals `"trusted-automation"`** — this half could, in isolation, be written as an `exclude` block instead (`exclude.any[].resources.namespaces: [trusted-automation]`). It's combined here specifically to demonstrate `preconditions.all` ANDing a structural-looking condition together with one (`request.operation`) that only preconditions can express — showing that once you need to combine "verb" logic with anything else, everything has to move into `preconditions`, because `match`/`exclude` has no operation field to combine it with in the same place.
- **The net effect** — the rule fires only for a brand-new Pod (`CREATE`) landing outside the exempted namespace. Every other case — a `CREATE` inside `trusted-automation`, or an `UPDATE` anywhere at all, even one that strips the `team` label from a Pod that already exists — bypasses the check entirely, because at least one of the two AND'd conditions is false.

---

## Step 3: Prove all four scenarios by hand

```bash
kubectl create ns trusted-automation
kubectl create ns team-ns

# 1. CREATE, no team label, ordinary namespace -> rejected
kubectl run bad-create -n team-ns --image=nginx --restart=Never
# Error ... check-team-label-create-only failed at path /metadata/labels/team/

# 2. CREATE, no team label, EXEMPT namespace -> admitted (namespace half of the AND is false)
kubectl run auto-pod -n trusted-automation --image=nginx --restart=Never
# pod/auto-pod created

# 3. CREATE, team label present, ordinary namespace -> admitted (rule ran and passed)
kubectl run good-create -n team-ns --image=nginx --restart=Never --labels=team=platform
# pod/good-create created

# 4. UPDATE removing the team label from good-create -> admitted (operation half of the AND is false)
kubectl label pod good-create -n team-ns team-
# pod/good-create unlabeled
```

Case 4 is the sharpest proof that both AND conditions actually matter: `good-create` is now sitting in the cluster with no `team` label at all, something the same rule would reject outright if it were a `CREATE`. It was only allowed to happen because the request's operation was `UPDATE`, which makes the first precondition false and skips the whole rule — the policy never even reaches `validate.pattern` for that request.

> [!NOTE]
> Both halves of this `preconditions.all` block happen to have `match`/`exclude` equivalents on their own: `match.resources.operations: [CREATE]` restricts the webhook to creation, and `exclude.resources.namespaces: [trusted-automation]` excludes the exempt namespace — combined, they would reproduce this exact policy's behavior without a `preconditions` block at all. This lab deliberately builds it as one `preconditions.all` instead, for two reasons that matter beyond this specific exercise: first, `request.operation` and `request.namespace` combined with `Equals`/`NotEquals` is precisely the shape you will reach for once *either* condition needs to be a real value comparison that `match`/`exclude` cannot express (a numeric threshold, a field deep in `spec`, a value from `context`); second, once a rule's gating logic needs even one such condition, keeping the whole gate in a single `preconditions` block — rather than splitting related conditions across `match`, `exclude`, and `preconditions` — is what real Kyverno policies do so the "when does this even run" logic lives in one visible place. Part 2 of the module course covers exactly where `match`/`exclude`'s vocabulary runs out.

Clean up when you're done (`kubectl delete pod bad-create good-create -n team-ns --ignore-not-found; kubectl delete pod auto-pod -n trusted-automation --ignore-not-found; kubectl delete ns team-ns trusted-automation --ignore-not-found`); the grading script creates and cleans up its own namespaces and Pods independently.
