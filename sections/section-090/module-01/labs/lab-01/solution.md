# Solution Guide: Autogen Rules

This guide builds one Pod-only `ClusterPolicy` rule and shows that autogen, on by default, is enough to make it also govern Deployments.

---

## Step 1: Write the policy

Create `policy.yaml`:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-team-label
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
```

Nothing here mentions `Deployment` anywhere. There is no `pod-policies.kyverno.io/autogen-controllers` annotation either — leaving it unset keeps autogen at its default scope (`DaemonSet`, `Deployment`, `Job`, `ReplicaSet`, `ReplicationController`, `StatefulSet`, and `CronJob`).

---

## Step 2: Apply it and find the rule Kyverno generated for you

```bash
kubectl apply -f policy.yaml
kubectl get clusterpolicy require-team-label -o yaml
```

Look under `status.autogen.rules` (not `spec.rules` — that still shows only the one rule you wrote). You should see a generated rule named `autogen-check-team-label` whose `match` covers `Deployment`, `DaemonSet`, `Job`, `ReplicaSet`, `ReplicationController`, and `StatefulSet`, with your pattern rewritten from `metadata.labels.team` to `spec.template.metadata.labels.team`. A second generated rule, `autogen-cronjob-check-team-label`, covers `CronJob` with the path rewritten one level deeper (`spec.jobTemplate.spec.template.metadata.labels.team`).

---

## Step 3: Prove it against a bad Pod, a bad Deployment, and a good Deployment

```bash
kubectl run bad-pod --image=nginx --restart=Never
# Error from server: admission webhook "validate.kyverno.svc-fail" denied the request: ...
# check-team-label failed at path /metadata/labels/team/

kubectl create deployment bad-deploy --image=nginx
# error: failed to create deployment: admission webhook "validate.kyverno.svc-fail" denied the request: ...
# autogen-check-team-label failed at path /spec/template/metadata/labels/team/

kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: good-deploy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: good-deploy
  template:
    metadata:
      labels:
        app: good-deploy
        team: platform
    spec:
      containers:
        - name: app
          image: nginx
EOF
# deployment.apps/good-deploy created
```

The bare Pod is rejected by your original rule (`check-team-label`). The bad Deployment is rejected by the rule Kyverno generated for you (`autogen-check-team-label`) — you never wrote that rule, and you never told Kyverno about `Deployment` at all. The good Deployment, with `team` on `spec.template.metadata.labels`, is admitted.

Clean up your scratch resources when you're done (`kubectl delete pod bad-pod --ignore-not-found; kubectl delete deployment bad-deploy good-deploy --ignore-not-found`); the grading script creates and cleans up its own test resources independently in a dedicated namespace.
