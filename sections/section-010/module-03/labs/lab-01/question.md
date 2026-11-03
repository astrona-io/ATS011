# Question

Kyverno is installed. Write one `ClusterPolicy` named `pod-anchors` with `validationFailureAction: Enforce` and `background: false`. It applies to Pods in the namespace `anchors` and has four `validate.pattern` rules:

1. A container whose image ends in `:latest` must set `imagePullPolicy: Always` (conditional anchor).
2. If a container sets `securityContext`, then `privileged` must be `false` (equality anchor, the block itself stays optional).
3. A Pod must not set `hostNetwork` at all (negation anchor).
4. At least one container must define a `readinessProbe` with an `httpGet` (existence anchor).
