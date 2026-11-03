# Solution

## Step 1: Save the policy

The `+()` anchor writes a field only when it is missing. The `(name)` anchor selects the sidecar containers. Save this as `clusterpolicy-mutation-anchors.yaml`:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: mutation-anchors
spec:
  background: false
  rules:
    - name: defaults
      match:
        any:
          - resources:
              kinds: ["Pod"]
              namespaces: ["anchor-lab"]
      mutate:
        patchStrategicMerge:
          metadata:
            labels:
              +(team): platform
          spec:
            +(automountServiceAccountToken): false
    - name: sidecar-hardening
      match:
        any:
          - resources:
              kinds: ["Pod"]
              namespaces: ["anchor-lab"]
      mutate:
        patchStrategicMerge:
          spec:
            containers:
              - (name): "sidecar-*"
                securityContext:
                  +(readOnlyRootFilesystem): true
```

## Step 2: Apply and submit

Apply it with `kubectl apply -f clusterpolicy-mutation-anchors.yaml`, then run `astrona submit -c sections/section-040/module-03/labs/lab-01`. Each check names the requirement it tests. If one fails, read its hint, fix the policy, apply it again and submit again.
