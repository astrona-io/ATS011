# Solution

## Step 1: Save the policy

The mutate rule runs before the validate rules for the same request, so the validate rule sees the label that the mutate rule added. Save this as `clusterpolicy-baseline.yaml`:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: baseline
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: add-managed-by
      match:
        any:
          - resources:
              kinds: ["ConfigMap"]
      mutate:
        patchStrategicMerge:
          metadata:
            labels:
              managed-by: platform
    - name: require-managed-by
      match:
        any:
          - resources:
              kinds: ["ConfigMap"]
      validate:
        message: "managed-by must be platform."
        pattern:
          metadata:
            labels:
              managed-by: platform
    - name: require-owner
      match:
        any:
          - resources:
              kinds: ["ConfigMap"]
      exclude:
        any:
          - resources:
              namespaces: ["legacy"]
      preconditions:
        all:
          - key: "{{ request.object.metadata.annotations.\"policy.example.com/skip-owner\" || '' }}"
            operator: NotEquals
            value: "true"
      validate:
        message: "ConfigMaps need an owner label."
        pattern:
          metadata:
            labels:
              owner: "?*"
```

## Step 2: Apply and submit

Apply it with `kubectl apply -f clusterpolicy-baseline.yaml`, then run `astrona submit -c sections/section-000/capstone/labs/lab-01`.
