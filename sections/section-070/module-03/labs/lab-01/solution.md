# Solution

## Step 1: Save the policy

Save this as `clusterpolicy-pod-functions.yaml`:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: pod-functions
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: name-format
      match:
        any:
          - resources:
              kinds: ["Pod"]
              namespaces: ["fn-lab"]
      validate:
        message: "Pod names must look like web-01."
        deny:
          conditions:
            all:
              - key: "{{ regex_match('^[a-z]+-[0-9][0-9]$', request.object.metadata.name) }}"
                operator: Equals
                value: false
    - name: owner-team
      match:
        any:
          - resources:
              kinds: ["Pod"]
              namespaces: ["fn-lab"]
      validate:
        message: "The owner annotation must start with platform/."
        deny:
          conditions:
            all:
              - key: "{{ to_upper(split(request.object.metadata.annotations.owner || '', '/')[0]) }}"
                operator: NotEquals
                value: PLATFORM
    - name: config-decoded
      match:
        any:
          - resources:
              kinds: ["Pod"]
              namespaces: ["fn-lab"]
      validate:
        message: "The config annotation must decode to ready."
        deny:
          conditions:
            all:
              - key: "{{ base64_decode(request.object.metadata.annotations.config || '') }}"
                operator: NotEquals
                value: ready
    - name: budget
      match:
        any:
          - resources:
              kinds: ["Pod"]
              namespaces: ["fn-lab"]
      validate:
        message: "A Pod may not use more than it requested."
        deny:
          conditions:
            all:
              - key: "{{ subtract(to_number(request.object.metadata.annotations.requested || '0'), to_number(request.object.metadata.annotations.used || '0')) }}"
                operator: LessThan
                value: 0
    - name: fresh-approval
      match:
        any:
          - resources:
              kinds: ["Pod"]
              namespaces: ["fn-lab"]
      validate:
        message: "The approval is older than 24 hours."
        deny:
          conditions:
            all:
              - key: "{{ time_since('', request.object.metadata.annotations.approved || '', '') }}"
                operator: DurationGreaterThan
                value: 24h
```

Each rule is one function call in one condition. The first four use the pattern "deny when the computed value is the wrong one".

## Step 2: Apply and submit

Apply it with `kubectl apply -f clusterpolicy-pod-functions.yaml`, then run `astrona submit -c sections/section-070/module-03/labs/lab-01`. If a check fails, read its hint, fix the matching rule, apply again and submit again. Each check tests one rule, so a failure points at one rule.
