# Solution Guide: Cleanup Policies

This guide grants Kyverno's cleanup controller permission to delete Pods, then applies a `ClusterCleanupPolicy` that sweeps every Pod labelled `lifecycle: ephemeral` once a minute.

---

## Step 1: Try it without RBAC first (optional, but instructive)

Write the policy on its own and apply it:

```yaml
apiVersion: kyverno.io/v2
kind: ClusterCleanupPolicy
metadata:
  name: cleanup-ephemeral-pods
spec:
  match:
    any:
      - resources:
          kinds:
            - Pod
          selector:
            matchLabels:
              lifecycle: ephemeral
  schedule: "* * * * *"
```

```bash
kubectl apply -f cleanup-policy.yaml
# Warning: kyverno.io/v2 ClusterCleanupPolicy is deprecated and will be removed in a future
# release; migrate to DeletingPolicy (policies.kyverno.io)
# Error from server: error when creating "cleanup-policy.yaml": admission webhook
# "kyverno-cleanup-controller.kyverno.svc" denied the request:
# cleanup controller has no permission to delete kind Pod
```

That error is not about your kubeconfig — you are cluster-admin on this lab cluster and you still get it. It is the `kyverno-cleanup-controller` ServiceAccount that has no rights to delete Pods.

---

## Step 2: Grant the permission

Kyverno's `kyverno:cleanup-controller` ClusterRole is an **aggregated** role: it absorbs the rules of any ClusterRole labelled `rbac.kyverno.io/aggregate-to-cleanup-controller: "true"`. So you never edit Kyverno's own role — you add your own.

Create `cleanup-rbac.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kyverno:cleanup-pods
  labels:
    rbac.kyverno.io/aggregate-to-cleanup-controller: "true"
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch", "delete"]
```

```bash
kubectl apply -f cleanup-rbac.yaml
# clusterrole.rbac.authorization.k8s.io/kyverno:cleanup-pods created
```

Two details that trip people up:

* **`resources: ["pods"]`, not `["Pod"]`.** RBAC takes API resource names — plural, lowercase. The `Kind` spelling belongs in the policy's `match` block. Getting this wrong produces exactly the same rejection as granting nothing.
* **`delete` alone is not enough.** The controller has to `list` candidates to find them and `get` them to evaluate anything about them. Grant all four verbs.

---

## Step 3: Apply the policy

Give RBAC aggregation a few seconds to propagate, then apply the same policy again:

```bash
kubectl apply -f cleanup-policy.yaml
# clustercleanuppolicy.kyverno.io/cleanup-ephemeral-pods created

kubectl get clustercleanuppolicy
# NAME                     SCHEDULE    AGE
# cleanup-ephemeral-pods   * * * * *   0s
```

The deprecation warning about `DeletingPolicy` still appears and is safe to ignore — `ClusterCleanupPolicy` is fully functional on Kyverno v1.19.1 and is what the KCA asks about.

---

## Step 4: Prove it sweeps the right Pod and spares the other

```bash
kubectl create ns cleanup-demo
kubectl run doomed -n cleanup-demo --image=nginx --restart=Never --labels=lifecycle=ephemeral
kubectl run keeper -n cleanup-demo --image=nginx --restart=Never --labels=lifecycle=permanent

kubectl get pods -n cleanup-demo --show-labels
# NAME     READY   STATUS    RESTARTS   AGE   LABELS
# doomed   1/1     Running   0          8s    lifecycle=ephemeral
# keeper   1/1     Running   0          8s    lifecycle=permanent
```

Now wait for the next minute boundary. This is the part that feels wrong the first time: nothing happens immediately, because a cleanup policy is a scheduled sweep rather than a trigger.

```bash
kubectl get pods -n cleanup-demo
# NAME     READY   STATUS    RESTARTS   AGE
# keeper   1/1     Running   0          71s
```

`doomed` is gone, `keeper` is untouched. Confirm the sweep actually ran on a cron boundary:

```bash
kubectl get clustercleanuppolicy cleanup-ephemeral-pods -o jsonpath='{.status}'
# {"lastExecutionTime":"2026-09-14T15:25:00Z"}
```

Note the `:00` seconds — ticks land on cron boundaries, not one minute after you applied the policy.

The deletion itself is completely ordinary:

```bash
kubectl get events -n cleanup-demo --sort-by=.lastTimestamp | tail -2
# 6s   Normal   Killing   pod/doomed   Stopping container doomed
```

Graceful termination, same as `kubectl delete` — not a force-removal.

---

## Step 5: Grade yourself

```bash
astrona submit -c sections/section-100/module-01/labs/lab-01
```

The grading script creates its own labelled and unlabelled Pods in a dedicated namespace and waits for a sweep, so it may take a couple of minutes to return.

Clean up your own scratch namespace when done:

```bash
kubectl delete ns cleanup-demo --ignore-not-found
```
