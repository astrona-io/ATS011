# Solution

## Step 1: Save the policy

Save this as `clusterpolicy-pod-anchors.yaml`:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: pod-anchors
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: latest-needs-always
      match:
        any:
          - resources:
              kinds: ["Pod"]
              namespaces: ["anchors"]
      validate:
        message: "Images tagged latest must use imagePullPolicy Always."
        pattern:
          spec:
            containers:
              - (image): "*:latest"
                imagePullPolicy: Always
    - name: not-privileged
      match:
        any:
          - resources:
              kinds: ["Pod"]
              namespaces: ["anchors"]
      validate:
        message: "Containers must not be privileged."
        pattern:
          spec:
            containers:
              - =(securityContext):
                  =(privileged): false
    - name: no-host-network
      match:
        any:
          - resources:
              kinds: ["Pod"]
              namespaces: ["anchors"]
      validate:
        message: "hostNetwork is not allowed."
        pattern:
          spec:
            X(hostNetwork): "null"
    - name: one-readiness-probe
      match:
        any:
          - resources:
              kinds: ["Pod"]
              namespaces: ["anchors"]
      validate:
        message: "At least one container needs an httpGet readinessProbe."
        pattern:
          spec:
            ^(containers):
              - readinessProbe:
                  httpGet:
                    path: "?*"
```

Apply it with `kubectl apply -f clusterpolicy-pod-anchors.yaml`, then run `astrona submit -c sections/section-010/module-03/labs/lab-01`.
