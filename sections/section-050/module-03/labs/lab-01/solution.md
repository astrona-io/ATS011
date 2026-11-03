# Solution

## Step 1: Save the cloneList policy

`cloneList` names a source namespace, the kinds, and a selector for opt-in objects. Save this as `clusterpolicy-share-config.yaml`:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: share-config
spec:
  rules:
    - name: clone-shared
      match:
        any:
          - resources:
              kinds: ["Namespace"]
              selector:
                matchLabels:
                  needs-shared: "true"
      generate:
        namespace: "{{ request.object.metadata.name }}"
        synchronize: true
        cloneList:
          namespace: shared-config
          kinds:
            - v1/ConfigMap
          selector:
            matchLabels:
              share: "true"
```

Apply it with `kubectl apply -f clusterpolicy-share-config.yaml`.

## Step 2: Save the foreach policy

The list splits the annotation, the context names the element, and the precondition skips `legacy`. Save this as `clusterpolicy-env-configmaps.yaml`:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: env-configmaps
spec:
  rules:
    - name: one-per-env
      match:
        any:
          - resources:
              kinds: ["Namespace"]
              selector:
                matchLabels:
                  env-set: "true"
      generate:
        synchronize: true
        foreach:
          - list: "request.object.metadata.annotations.envs | split(@, ',')"
            context:
              - name: env
                variable:
                  jmesPath: element
            preconditions:
              all:
                - key: "{{ env }}"
                  operator: NotEquals
                  value: legacy
            apiVersion: v1
            kind: ConfigMap
            name: "env-{{ env }}"
            namespace: "{{ request.object.metadata.name }}"
            data:
              data:
                environment: "{{ env }}"
```

Apply it with `kubectl apply -f clusterpolicy-env-configmaps.yaml`.

## Step 3: Submit

Run `astrona submit -c sections/section-050/module-03/labs/lab-01`. The checks create temporary namespaces and wait up to 2 minutes for the generated ConfigMaps.
