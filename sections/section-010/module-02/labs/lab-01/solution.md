# Solution

## Step 1: Save the policy

A deny rule rejects when its conditions are true, so each condition states the **bad** case. Save this as `clusterpolicy-deployment-guardrails.yaml`:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: deployment-guardrails
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: replica-cap
      match:
        any:
          - resources:
              kinds: ["Deployment"]
              namespaces: ["shop"]
      validate:
        message: "A Deployment may have at most 5 replicas. Found {{ request.object.spec.replicas }}."
        deny:
          conditions:
            all:
              - key: "{{ request.object.spec.replicas || `1` }}"
                operator: GreaterThan
                value: 5
    - name: allowed-tier
      match:
        any:
          - resources:
              kinds: ["Deployment"]
              namespaces: ["shop"]
      validate:
        message: "The tier label must be frontend, backend or batch."
        deny:
          conditions:
            all:
              - key: "{{ request.object.metadata.labels.tier || '' }}"
                operator: AnyNotIn
                value: ["frontend", "backend", "batch"]
    - name: approved-registries
      match:
        any:
          - resources:
              kinds: ["Deployment"]
              namespaces: ["shop"]
      validate:
        message: "Images must come from ghcr.io or registry.example.com."
        foreach:
          - list: "request.object.spec.template.spec.containers"
            deny:
              conditions:
                all:
                  - key: "{{ regex_match('^(ghcr.io|registry.example.com)/', '{{ element.image }}') }}"
                    operator: Equals
                    value: false
```

Apply it with `kubectl apply -f clusterpolicy-deployment-guardrails.yaml`.

## Step 2: Submit

Run `astrona submit -c sections/section-010/module-02/labs/lab-01`.
