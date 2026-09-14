# Part 2: Existence, Negation, and Global Anchors

## The existence anchor `^()`

Module 1 established that a plain list pattern is matched by position, and that `foreach` is the tool for "every element must comply". The remaining shape is the opposite one: **at least one** element must comply, and the rest are free.

```yaml
validate:
  message: "At least one container must define a readinessProbe."
  pattern:
    spec:
      ^(containers):
        - readinessProbe:
            httpGet:
              path: "?*"
```

`^()` works on lists only, and it means: *this pattern must match at least one element of this array.* Not the first, not all — any one of them.

That distinction is easy to state and easy to get backwards, so test it with the case that separates the two readings: a Pod where only the **second** container complies.

> [!TIP]
> **Try it — one compliant element is enough**
>
> ```sh
> kubectl apply -f needs-a-probe.yaml
>
> kubectl apply -f - <<'EOF'
> apiVersion: v1
> kind: Pod
> metadata: {name: probe-ok}
> spec:
>   containers:
>     - {name: side, image: "nginx:1.27"}
>     - name: app
>       image: "nginx:1.27"
>       readinessProbe: {httpGet: {path: /healthz, port: 80}}
> EOF
>
> kubectl apply -f - <<'EOF'
> apiVersion: v1
> kind: Pod
> metadata: {name: probe-bad}
> spec:
>   containers:
>     - {name: side, image: "nginx:1.27"}
>     - {name: app, image: "nginx:1.27"}
> EOF
> ```
>
> Expect something like:
>
> ```text
> pod/probe-ok created
>
> needs-a-probe:
>   at-least-one-container-with-readiness: 'validation error: At least one container must define a readinessProbe. rule at-least-one-container-with-readiness failed at path /spec/containers/'
> ```
>
> `probe-ok` has a container with no probe at all and is admitted — that would be
> rejected by a `foreach`, and admitted-for-the-wrong-reason by a positional
> pattern that only ever checked index 0. Note the failure path on `probe-bad`:
> `/spec/containers/`, the list itself, because no single element is at fault.

## The negation anchor `X()`

`X()` is the simplest of the five: **this key must not be present.** The value is not evaluated — write `"null"` and it is ignored.

```yaml
=(volumes):
  - X(hostPath): "null"
```

You met this in Part 1 as the inside half of the `hostPath` ban. On its own it reads: for each element of `volumes`, the key `hostPath` must be absent. A volume that is an `emptyDir`, a `configMap`, a PVC — all fine. A volume with a `hostPath` key — rejected, whatever the path says.

The `"null"` is worth explaining because it looks like it means something. It does not. `X()` checks presence only, and the value is a placeholder the schema requires. Writing `X(hostPath): "/tmp"` does not restrict the ban to `/tmp`; it bans `hostPath` entirely, exactly as before. If you want "hostPath is allowed but not under `/var/lib`", that is a job for `=()` plus a negated value (`path: "!/var/lib"`), not for `X()`.

## The global anchor `<()`

The conditional anchor's `if` reaches exactly as far as its siblings inside one element. Sometimes the condition should gate the **entire rule**, including fields in a completely different part of the resource.

The canonical case: *a Pod pulling from the corporate registry must declare an `imagePullSecret`.* The condition is about a container's image; the requirement is about `spec.imagePullSecrets`, which is not a sibling of anything inside `containers`.

```yaml
validate:
  message: "Pods using corp.reg.com images must set imagePullSecrets."
  pattern:
    spec:
      containers:
        - <(image): "corp.reg.com/*"
      imagePullSecrets:
        - name: "my-registry-secret"
```

`<()` means: if this condition is false, **skip the whole rule**. If it is true, every other part of the pattern applies — including parts nowhere near the anchor.

> [!TIP]
> **Try it — a condition that reaches across the resource**
>
> ```sh
> kubectl apply -f corp-registry-needs-secret.yaml
>
> kubectl apply -f - <<'EOF'
> apiVersion: v1
> kind: Pod
> metadata: {name: corp-bad}
> spec:
>   containers: [{name: app, image: "corp.reg.com/app:1.0"}]
> EOF
>
> kubectl run corp-na --image=nginx:1.27 --restart=Never
> ```
>
> Expect something like:
>
> ```text
> corp-registry-needs-secret:
>   pull-secret-for-corp-images: 'validation error: Pods using corp.reg.com images must set imagePullSecrets. rule pull-secret-for-corp-images failed at path /spec/imagePullSecrets/'
>
> pod/corp-na created
> ```
>
> The failure path is `/spec/imagePullSecrets/` — a field in a different branch of
> the resource from the anchor that triggered the check. And `corp-na`, which also
> has no pull secret, is admitted, because its image did not satisfy the global
> condition and the rule was skipped in its entirety.

If you tried to write that with `()` instead, the `if` would only govern fields inside the same container element, and `imagePullSecrets` would be required unconditionally on every Pod.

## Choosing between the five

| Anchor | Question it asks | Use when |
| :--- | :--- | :--- |
| `()` | does this field have this value? | a check applies only to elements that look a certain way |
| `=()` | does this field exist? | you need to reach inside an optional block |
| `^()` | does at least one element match? | the requirement is "some", not "all" |
| `X()` | is this field absent? | a field is forbidden outright |
| `<()` | is this condition true, for the whole rule? | the condition and the requirement live in different parts of the resource |

## Anchors or a deny rule?

Module 2's `deny` conditions can express most of what anchors can, and the reverse is also largely true. The honest guidance is about readability rather than capability:

* **Anchors** keep the check in the same shape as the resource, so a reader sees "this field, when it looks like this, requires that field". They are the better fit when the condition and the requirement are structurally close.
* **`deny` conditions** are better when the test is a comparison — a number, a duration, a set membership — because a pattern has no vocabulary for those beyond simple wildcards.

The decisive question is usually: *is this a statement about shape, or a statement about values?* Shape takes anchors; values take conditions. A rule that is straining to express a numeric comparison through anchors, or one that reconstructs a resource's whole structure inside a `key` expression, is a rule reaching for the wrong tool.

> [!WARNING]
> **Common pitfalls**
>
> - **Using `^()` on something that is not a list.** It is defined for arrays only.
> - **Reading `X(field): "/some/value"` as a restriction on that value.** `X()` ignores the value entirely and forbids the key outright.
> - **Using `()` where the requirement lives elsewhere in the resource.** A conditional anchor governs its own siblings; crossing branches needs `<()`.
> - **Assuming `^()` means "the first element".** It means any one of them, and a compliant element at the end of a long list satisfies it.
> - **Forgetting that all of these skip rather than fail.** A rule whose anchors never match is a rule that never ran.

## Section recap

`^()` requires at least one list element to match, which is the shape neither a positional pattern nor a `foreach` provides. `X()` forbids a key outright and ignores its value. `<()` gates the whole rule on a condition, letting the condition and the requirement live in different branches of the resource. Between anchors and `deny` conditions, the deciding question is whether the requirement is about shape or about values.
