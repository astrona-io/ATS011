# Solution

## Step 1: Save the policy

Both rules read the `images` variable. The first uses `AnyNotIn` so that one bad registry denies the Pod. The second uses `AnyIn` so that one `latest` tag denies it. The rules match `Pod` only, and Kyverno generates the Deployment rules from them. Save this as `clusterpolicy-image-source-rules.yaml`:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: image-source-rules
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: allowed-registries
      match:
        any:
          - resources:
              kinds: ["Pod"]
              namespaces: ["image-lab"]
      validate:
        message: "Images must come from docker.io or ghcr.io."
        deny:
          conditions:
            any:
              - key: "{{ images.containers.*.registry }}"
                operator: AnyNotIn
                value: ["docker.io", "ghcr.io"]
    - name: no-latest-tag
      match:
        any:
          - resources:
              kinds: ["Pod"]
              namespaces: ["image-lab"]
      validate:
        message: "The latest tag is not allowed."
        deny:
          conditions:
            any:
              - key: "{{ images.containers.*.tag }}"
                operator: AnyIn
                value: ["latest"]
```

## Step 2: Apply it and submit

Apply the policy with `kubectl apply -f clusterpolicy-image-source-rules.yaml`, wait a few seconds for the webhooks to update, then run `astrona submit -c sections/section-060/module-03/labs/lab-01`.

If a check fails, the message names the object that was admitted or rejected by mistake. Read it against the rule that should have decided that case.
