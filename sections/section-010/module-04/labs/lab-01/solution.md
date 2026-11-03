# Solution

## Step 1: Save the policy

Save this as `clusterpolicy-pss-baseline.yaml`:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: pss-baseline
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: baseline
      match:
        any:
          - resources:
              kinds: ["Pod"]
              namespaces: ["pss-lab"]
      validate:
        message: "The Pod breaks the baseline Pod Security Standard."
        podSecurity:
          level: baseline
          version: latest
          exclude:
            - controlName: Capabilities
              images:
                - "registry.example.com/net-tool*"
```

Apply it with `kubectl apply -f clusterpolicy-pss-baseline.yaml`, then run `astrona submit -c sections/section-010/module-04/labs/lab-01`.
