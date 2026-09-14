# Part 1: Conditional and Equality Anchors

## The conditional anchor `()`

Start with the requirement: *a container using a `:latest` image must set `imagePullPolicy: Always`.* Containers on pinned tags are not the rule's business.

```yaml
validate:
  message: "A container using a :latest image must set imagePullPolicy: Always."
  pattern:
    spec:
      containers:
        - (image): "*:latest"
          imagePullPolicy: "Always"
```

The parentheses turn `image` from a field the pattern *requires* into a field the pattern *tests*. Read the element as an if/then:

* **if** `image` matches `*:latest`
* **then** every sibling field in this element — here `imagePullPolicy` — must match too

And when the anchor does not match, the siblings are not checked at all. That is the whole point: a container on `nginx:1.27` is not required to set anything, because the `if` was false.

Three outcomes are worth separating, and the third is the one people forget exists.

> [!TIP]
> **Try it — one rule, three verdicts**
>
> ```sh
> kubectl apply -f latest-needs-always.yaml
>
> kubectl apply -f - <<'EOF'
> apiVersion: v1
> kind: Pod
> metadata: {name: a-latest}
> spec:
>   containers: [{name: app, image: "nginx:latest", imagePullPolicy: IfNotPresent}]
> EOF
>
> kubectl apply -f - <<'EOF'
> apiVersion: v1
> kind: Pod
> metadata: {name: b-latest}
> spec:
>   containers: [{name: app, image: "nginx:latest", imagePullPolicy: Always}]
> EOF
>
> kubectl apply -f - <<'EOF'
> apiVersion: v1
> kind: Pod
> metadata: {name: c-pinned}
> spec:
>   containers: [{name: app, image: "nginx:1.27", imagePullPolicy: IfNotPresent}]
> EOF
> ```
>
> Expect something like:
>
> ```text
> latest-needs-always:
>   latest-tag-pull-policy: 'validation error: A container using a :latest image must set imagePullPolicy: Always. rule latest-tag-pull-policy failed at path /spec/containers/0/imagePullPolicy/'
>
> pod/b-latest created
> pod/c-pinned created
> ```
>
> `a-latest` matched the anchor and failed the sibling. `b-latest` matched and
> satisfied it. `c-pinned` has the *same* `imagePullPolicy: IfNotPresent` that got
> `a-latest` rejected — and is admitted, because the anchor did not match and the
> sibling was never examined.

Note where the failure points: `/spec/containers/0/imagePullPolicy/`, the **sibling**, not the anchored field. The anchor is the question; the siblings are the answer being graded. That is a reliable way to read an anchor failure — the path names what was wrong, not what selected the element.

> [!NOTE]
> An anchored key still supports the ordinary wildcard vocabulary from Module 1. `(image): "*:latest"` is a glob. You can also negate inside the value with `!`, so `imagePullPolicy: "!IfNotPresent"` expresses "anything except `IfNotPresent`" — which is subtly weaker than requiring `Always`, and is the form you will see in Kyverno's own published policies.

## The equality anchor `=()`

`()` asks *does this field have this value?* `=()` asks a narrower question: *does this field exist at all?* If it does, the pattern nested under it is enforced; if it does not, the check is skipped.

That is exactly what you need for an optional block. Consider: *`hostPath` volumes are forbidden* — but a Pod with no `volumes` at all must not be rejected for failing to have a `volumes` list.

```yaml
validate:
  message: "hostPath volumes are not permitted."
  pattern:
    spec:
      =(volumes):
        - X(hostPath): "null"
```

`=(volumes)` means "if this Pod has a `volumes` list, look inside it". Without the anchor, a plain `volumes:` key in the pattern would *require* every Pod to declare volumes, and a perfectly ordinary Pod with none would be rejected for the wrong reason entirely.

(`X(hostPath)` is the negation anchor — "this key must not exist" — and Part 2 covers it properly. It appears here because the equality anchor is rarely useful alone; its job is to make it safe to reach *into* something optional.)

> [!TIP]
> **Try it — optional means optional**
>
> ```sh
> kubectl apply -f no-hostpath.yaml
>
> kubectl apply -f - <<'EOF'
> apiVersion: v1
> kind: Pod
> metadata: {name: hp-bad}
> spec:
>   volumes: [{name: host, hostPath: {path: /tmp}}]
>   containers: [{name: app, image: "nginx:1.27"}]
> EOF
>
> kubectl apply -f - <<'EOF'
> apiVersion: v1
> kind: Pod
> metadata: {name: hp-ok}
> spec:
>   volumes: [{name: scratch, emptyDir: {}}]
>   containers: [{name: app, image: "nginx:1.27"}]
> EOF
>
> kubectl run hp-none --image=nginx:1.27 --restart=Never
> ```
>
> Expect something like:
>
> ```text
> no-hostpath:
>   forbid-hostpath: 'validation error: hostPath volumes are not permitted. rule forbid-hostpath failed at path /spec/volumes/0/hostPath/'
>
> pod/hp-ok created
> pod/hp-none created
> ```
>
> The Pod with a `hostPath` volume is rejected. The Pod with an `emptyDir` volume
> passes — it has a `volumes` list, the anchor opened it, and nothing inside was
> a `hostPath`. And the Pod with no volumes at all passes untouched, which is the
> case `=()` exists to protect.

## Skipped is not the same as passed

Both anchors in this part share one behaviour, and it is the thing to carry forward: **when the anchor does not apply, the check is skipped, not passed.**

For an `Enforce` policy the practical outcome looks identical — the resource is admitted either way. The difference shows up in reports (Section 030), where a skipped rule records `skip` and a satisfied rule records `pass`. If you are using reports to answer "how many workloads actually comply with this rule", a large `skip` count means most of them were never assessed — which is a very different situation from most of them complying, and one that a naive reading of a green dashboard will get wrong.

> [!WARNING]
> **Common pitfalls**
>
> - **Naming an optional field without `=()`.** A plain `volumes:` in a pattern requires the key to exist. Every Pod without volumes is then rejected for a reason the rule never intended.
> - **Expecting the anchored field itself to be enforced.** `(image): "*:latest"` does not require images to be `:latest`; it selects the ones that are.
> - **Reading a skipped rule as a passing one.** In reports they are distinct results, and conflating them overstates compliance.
> - **Assuming an anchor's `if` reaches beyond its own element.** A conditional anchor inside a list element governs only that element's siblings. For a condition that should gate the entire rule, Part 2's global anchor `<()` is the one you want.

## Section recap

`()` is an if/then inside a pattern: when the anchored field matches, its sibling fields become mandatory; when it does not, they are skipped. `=()` is the existence-only form, used to reach safely into an optional block without requiring the block itself. Both skip rather than pass when they do not apply, and the failure path names the sibling that failed, not the anchor that selected it.
