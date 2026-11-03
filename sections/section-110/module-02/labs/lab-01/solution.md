# Solution

## Step 1: Save the MutatingPolicy

Save this as `mutating-policy.yaml`:

```yaml
apiVersion: policies.kyverno.io/v1
kind: MutatingPolicy
metadata:
  name: add-managed-by
spec:
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE"]
        resources: ["pods"]
  mutations:
    - patchType: ApplyConfiguration
      applyConfiguration:
        expression: >
          Object{ metadata: Object.metadata{ labels: {"managed-by": "kyverno-mutatingpolicy"} } }
```

Apply it with `kubectl apply -f mutating-policy.yaml`.

## Step 2: Save the DeletingPolicy

Save this as `deleting-policy.yaml`:

```yaml
apiVersion: policies.kyverno.io/v1
kind: DeletingPolicy
metadata:
  name: sweep-ephemeral
spec:
  schedule: "* * * * *"
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  conditions:
    - name: only-ephemeral
      expression: "has(object.metadata.labels) && object.metadata.labels['lifecycle'] == 'ephemeral'"
```

Apply it with `kubectl apply -f deleting-policy.yaml`, then run `astrona submit -c sections/section-110/module-02/labs/lab-01`.
