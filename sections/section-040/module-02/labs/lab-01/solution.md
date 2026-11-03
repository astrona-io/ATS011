# Solution

## Step 1: Save the policy

The element name selects the list entry to patch and `element.image` reads its current value. Save this as `clusterpolicy-internal-registry.yaml`:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: internal-registry
spec:
  background: false
  rules:
    - name: prefix-images
      match:
        any:
          - resources:
              kinds: ["Pod"]
              namespaces: ["mutate-lab"]
      mutate:
        foreach:
          - list: "request.object.spec.containers"
            preconditions:
              all:
                - key: "{{ element.image }}"
                  operator: NotEquals
                  value: "registry.internal/*"
            patchStrategicMerge:
              spec:
                containers:
                  - name: "{{ element.name }}"
                    image: "registry.internal/{{ element.image }}"
```

Apply it with `kubectl apply -f clusterpolicy-internal-registry.yaml`, then run `astrona submit -c sections/section-040/module-02/labs/lab-01`.
