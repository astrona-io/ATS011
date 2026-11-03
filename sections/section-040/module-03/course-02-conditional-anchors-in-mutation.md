# Part 2: Conditional Anchors in Mutation

## An anchor as a filter

Module 1 used `(name): "*"` to reach every container. The parentheses make `name` a **conditional anchor**: an "if". The element is patched only when its `name` matches the value, and the other fields in that element describe the change.

Because the value may use wildcards (`*` for any run of characters, `?` for one character), the anchor can select a subset:

```yaml
mutate:
  patchStrategicMerge:
    spec:
      containers:
        - (name): "sidecar-*"
          securityContext:
            readOnlyRootFilesystem: true
```

Containers named `sidecar-log` or `sidecar-proxy` get a read-only root filesystem. A container named `app` does not match, so it is not touched. `(name): "*"` is just the widest version of the same filter.

Only `patchStrategicMerge` supports conditional anchors. They are evaluated first, and the plain fields apply only for elements where the condition is true.

<!-- astrona:playground:renew -->
> [!TIP]
> **Try it — patch only the sidecars**
>
> Save this as `sidecar-ro.yaml` and apply it:
>
> ```yaml
> apiVersion: kyverno.io/v1
> kind: ClusterPolicy
> metadata:
>   name: sidecar-ro
> spec:
>   background: false
>   rules:
>     - name: sidecar-readonly
>       match:
>         any:
>           - resources:
>               kinds: ["Pod"]
>       mutate:
>         patchStrategicMerge:
>           spec:
>             containers:
>               - (name): "sidecar-*"
>                 securityContext:
>                   readOnlyRootFilesystem: true
> ```
>
> ```sh
> kubectl apply -f sidecar-ro.yaml
> kubectl apply -f - <<'EOF2'
> apiVersion: v1
> kind: Pod
> metadata: {name: sc-demo}
> spec:
>   containers:
>     - {name: app, image: "nginx:1.27"}
>     - {name: sidecar-log, image: "busybox:1.36", command: ["sleep","3600"]}
> EOF2
> kubectl get pod sc-demo -o jsonpath='{range .spec.containers[*]}{.name}={.securityContext.readOnlyRootFilesystem}{"\n"}{end}'
> ```
>
> Expect `app=` (empty) and `sidecar-log=true`.

## Combining the two anchors

The conditional anchor chooses *which elements*. The `+()` anchor chooses *whether to write a field* on those elements. Together they give a default for a subset, which respects choices the owner made:

```yaml
mutate:
  patchStrategicMerge:
    spec:
      containers:
        - (name): "sidecar-*"
          securityContext:
            +(readOnlyRootFilesystem): true
            +(allowPrivilegeEscalation): false
```

A sidecar that sets `readOnlyRootFilesystem: false` itself keeps `false`; a sidecar that says nothing gets `true`. The `app` container is untouched either way. Compare with the version in the previous section, which forced `true` on every sidecar.

> [!TIP]
> **Try it — a default on matching elements only**
>
> Edit `sidecar-ro.yaml` so the field reads `+(readOnlyRootFilesystem): true`, apply it, then create a Pod with `sidecar-a` (no securityContext) and `sidecar-b` (with `securityContext: {readOnlyRootFilesystem: false}`) plus an `app` container. Expect `sidecar-a=true`, `sidecar-b=false`, and `app` unchanged.

## Limits to remember

- A conditional anchor on a list element decides that element only. Elements that do not match are skipped, not rejected.
- Nested conditional anchors are not supported.
- The anchor value is a pattern on a single field, usually `name`. For a decision that depends on several fields or on a computed value, use `preconditions` or `foreach` from Module 2.

> [!WARNING]
> **Common pitfalls**
>
> - **Forgetting the parentheses.** `name: "sidecar-*"` is not a filter; it is a literal value to write.
> - **Assuming the filter rejects non-matching containers.** It only skips them.
> - **Writing `sidecar*` when the names are `my-sidecar`.** The pattern must match the whole name.
> - **Forcing a value when you meant a default.** Add `+()` around the key if owners may choose their own.

## Your mission: Mutation Anchors Lab

You can now supply defaults with `+()` and aim a patch at chosen list elements with a conditional anchor. The mission asks you to write one policy that defaults a Pod label and a Pod setting, and hardens only sidecar containers, without overwriting what the owner set.

Pause the playground, start the lab, and submit your work as often as you like:

```sh
astrona stop ats-011-playground-0403
astrona run --git ssh://git@github.com/astrona-io/ATS011.git -c sections/section-040/module-03/labs/lab-01
astrona submit -c sections/section-040/module-03/labs/lab-01
```

When the lab passes, remove it and return to the playground:

```sh
astrona destroy ats-011-lab-043
astrona start ats-011-playground-0403
```
