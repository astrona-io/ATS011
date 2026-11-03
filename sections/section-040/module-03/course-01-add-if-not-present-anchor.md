# Part 1: The Add-If-Not-Present Anchor

## Overwrite versus default

A plain `patchStrategicMerge` fragment states what the resource must look like afterwards. If the fragment says `team: platform`, every matching resource ends up with `team: platform`, whatever value the owner chose.

That is right for a rule that enforces a value. It is wrong for a rule that only supplies a *default*. A team that deliberately labelled its Pod `team: payments` does not want a policy to replace that with `platform`.

The `+()` anchor, the **add-if-not-present** anchor, writes a field only when that field is missing:

```yaml
mutate:
  patchStrategicMerge:
    metadata:
      labels:
        +(team): platform
```

Read it as: *if there is no `team` label, add `team: platform`; if there is one, leave it alone.* The anchor goes around the **key**, in the same position as `(name)`, and the value after the colon is what gets written when the key is absent.

<!-- astrona:playground:renew -->
> [!TIP]
> **Try it — a default that respects the owner**
>
> Save this as `default-team.yaml` and apply it:
>
> ```yaml
> apiVersion: kyverno.io/v1
> kind: ClusterPolicy
> metadata:
>   name: default-team
> spec:
>   background: false
>   rules:
>     - name: add-team-label
>       match:
>         any:
>           - resources:
>               kinds: ["Pod"]
>       mutate:
>         patchStrategicMerge:
>           metadata:
>             labels:
>               +(team): platform
> ```
>
> ```sh
> kubectl apply -f default-team.yaml
> kubectl run no-label --image=nginx:1.27
> kubectl run has-label --image=nginx:1.27 --labels=team=payments
> kubectl get pod no-label has-label --show-labels
> ```
>
> Expect `no-label` to carry `team=platform` and `has-label` to keep `team=payments`.
> Now change the policy to a plain `team: platform` (no `+()`), create two more
> Pods the same way, and compare: the Pod that chose `payments` is overwritten.

## Other fields, same pattern

The anchor works on any scalar or object field, not only labels. A common use is a safe default for a Pod-level setting:

```yaml
mutate:
  patchStrategicMerge:
    spec:
      +(automountServiceAccountToken): false
```

A Pod that does not mention `automountServiceAccountToken` gets `false`. A Pod that sets it to `true` keeps `true`, because the field is present. Several `+()` anchors may sit side by side under the same parent, and each is decided on its own:

```yaml
    spec:
      securityContext:
        +(runAsNonRoot): true
        +(runAsUser): 1000
```

If the Pod already sets `runAsUser: 2000` but not `runAsNonRoot`, only `runAsNonRoot` is added.

One caution: do not rely on `+()` for a field the API server defaults itself. By the time the webhook sees the Pod, a defaulted field such as `imagePullPolicy` is usually already present, so the anchor finds it and does nothing.

## Why this is safe to run again

Module 2 explained that a rule runs again on UPDATE and that rules deriving a value from the old one compound. A `+()` patch cannot compound. Once the field exists, the next run finds it and writes nothing. The rule is idempotent by construction, with no `preconditions` guard needed.

The price is that a `+()` rule never *corrects* anything. A Pod that already has a wrong value keeps it. If the policy must force a value, use a plain field and accept the overwrite. If it must only fill gaps, use `+()`. Choose by asking which of the two you mean.

> [!WARNING]
> **Common pitfalls**
>
> - **Using a plain field when you meant a default.** The rule silently replaces values owners chose on purpose.
> - **Expecting `+()` to fix a wrong value.** It only acts when the field is missing.
> - **Using `+()` on a list.** The anchor is meant for scalar and object fields; do not use it on arrays outside a `foreach`.
> - **Using `+()` on a server-defaulted field.** The field is already there, so nothing happens.
> - **Quoting the key wrongly.** The anchor is part of the key (`+(team)`), not of the value.
