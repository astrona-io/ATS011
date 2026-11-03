# Solution

## Step 1: Save the policy

Save this as `clusterpolicy-replica-limit.yaml`:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: replica-limit
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: max-replicas
      match:
        any:
          - resources:
              kinds: ["Deployment"]
              namespaces: ["ctx-lab"]
      context:
        - name: cm
          configMap:
            name: limits
            namespace: policy-config
        - name: limit
          variable:
            jmesPath: "to_number(cm.data.\"max-replicas\")"
      validate:
        message: "At most {{ limit }} replicas are allowed."
        deny:
          conditions:
            all:
              - key: "{{ request.object.spec.replicas || `1` }}"
                operator: GreaterThan
                value: "{{ limit }}"
```

Apply it with `kubectl apply -f clusterpolicy-replica-limit.yaml`, then run `astrona submit -c sections/section-070/module-02/labs/lab-01`.
