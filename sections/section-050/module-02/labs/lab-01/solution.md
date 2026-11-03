# Solution

## Step 1: Save the policy

`generateExisting` backfills existing namespaces. `orphanDownstreamOnPolicyDelete` keeps generated objects when the policy is removed. Save this as `clusterpolicy-standard-defaults.yaml`:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: standard-defaults
spec:
  rules:
    - name: platform-defaults
      match:
        any:
          - resources:
              kinds: ["Namespace"]
              selector:
                matchLabels:
                  tier: standard
      generate:
        apiVersion: v1
        kind: ConfigMap
        name: platform-defaults
        namespace: "{{ request.object.metadata.name }}"
        synchronize: true
        generateExisting: true
        orphanDownstreamOnPolicyDelete: true
        data:
          data:
            log-level: info
```

Apply it with `kubectl apply -f clusterpolicy-standard-defaults.yaml`. Wait about a minute, then check `kubectl get configmap platform-defaults -A`.

## Step 2: Submit

Run `astrona submit -c sections/section-050/module-02/labs/lab-01`.
