# Solution

## Step 1: Save the policy

Save this as `clusterpolicy-assert-pods.yaml`:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: assert-pods
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: pod-rules
      match:
        any:
          - resources:
              kinds: ["Pod"]
              namespaces: ["assert-lab"]
      validate:
        message: "Pods must not use the default service account or a :latest image, and every container needs a memory limit."
        assert:
          object:
            spec:
              (serviceAccountName == 'default'): false
              ~.containers:
                (ends_with(image, ':latest')): false
                (resources.limits.memory != `null`): true
```

The key `~.containers` makes Kyverno check each container on its own. The keys in parentheses are JMESPath expressions. The value after the colon is the result that each expression must return.

## Step 2: Apply the policy

```sh
kubectl apply -f clusterpolicy-assert-pods.yaml
```

Kyverno prints a deprecation warning for `kyverno.io/v1`. You can ignore it.

## Step 3: Submit

```sh
astrona submit -c sections/section-010/module-05/labs/lab-01
```

Each failed check prints a message and a hint. Fix the policy, apply it again, and submit again.
