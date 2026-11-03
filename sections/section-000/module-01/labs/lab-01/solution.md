# Solution

## Step 1: Save the namespaced Policy

Save this as `policy-require-owner.yaml`:

```yaml
apiVersion: kyverno.io/v1
kind: Policy
metadata:
  name: require-owner
  namespace: staging
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: owner-label
      match:
        any:
          - resources:
              kinds: ["ConfigMap"]
      validate:
        message: "ConfigMaps in staging need an owner label."
        pattern:
          metadata:
            labels:
              owner: "?*"
```

Apply it with `kubectl apply -f policy-require-owner.yaml`. A `Policy` lives in one namespace and only sees resources there.

## Step 2: Save the ClusterPolicy with overrides

Save this as `clusterpolicy-require-cost-center.yaml`:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-cost-center
spec:
  validationFailureAction: Audit
  validationFailureActionOverrides:
    - action: Enforce
      namespaces: ["production"]
  background: false
  rules:
    - name: cost-center-label
      match:
        any:
          - resources:
              kinds: ["ConfigMap"]
      validate:
        message: "ConfigMaps need a cost-center label."
        pattern:
          metadata:
            labels:
              cost-center: "?*"
```

Apply it with `kubectl apply -f clusterpolicy-require-cost-center.yaml`.

## Step 3: Submit

Run `astrona submit -c sections/section-000/module-01/labs/lab-01`. The grader tries ConfigMaps in each namespace and reads your policy objects.
