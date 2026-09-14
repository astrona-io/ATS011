# Part 1: foreach in a mutate rule

## A change computed from what is already there

The requirement: every container image should be pulled through an internal mirror, so `nginx:1.27` becomes `mirror.local/nginx:1.27`.

Module 1's `(name)` anchor cannot express that. The anchor applies one fixed fragment to every matching element — it can set every container's `imagePullPolicy` to `IfNotPresent`, because that value is the same for all of them. Here each container needs a *different* new image, and the new value depends on the old one.

`mutate.foreach` gives you the loop and the current element:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: prefix-images
spec:
  background: false
  rules:
    - name: rewrite-to-mirror
      match:
        any:
          - resources:
              kinds:
                - Pod
      mutate:
        foreach:
          - list: "request.object.spec.containers"
            patchStrategicMerge:
              spec:
                containers:
                  - name: "{{ element.name }}"
                    image: "mirror.local/{{ element.image }}"
```

Read the `foreach` entry as three parts:

* **`list`** — a JMESPath expression naming the array to iterate. `request.object.spec.containers` is "the containers of the incoming resource".
* **`element`** — the current item, available inside the rule body as a variable.
* **the rule body** — here `patchStrategicMerge`, applied once per element.

The `name: "{{ element.name }}"` line is doing quiet but essential work. The patch is still a strategic merge, so it still needs the list's merge key to identify *which* container this fragment applies to. Without it, the fragment would match no container and be inserted as a new nameless one — the failure Module 1 met with a missing `(name)` anchor, reappearing here for the same underlying reason.

> [!TIP]
> **Try it — two containers, two different rewrites**
>
> ```sh
> kubectl apply -f prefix-images.yaml
>
> kubectl apply -f - <<'EOF'
> apiVersion: v1
> kind: Pod
> metadata: {name: fe-mutate}
> spec:
>   containers:
>     - {name: app, image: "nginx:1.27"}
>     - {name: side, image: "busybox:1.36", command: ["sleep","3600"]}
> EOF
>
> kubectl get pod fe-mutate -o jsonpath='{range .spec.containers[*]}{.name}={.image}{"\n"}{end}'
> ```
>
> Expect something like:
>
> ```text
> app=mirror.local/nginx:1.27
> side=mirror.local/busybox:1.36
> ```
>
> Each container got a different new value, and each one was derived from the
> image that container already had. No single strategic-merge fragment could
> have produced both.

## foreach or the `(name)` anchor?

Both reach every element. The question is where the new value comes from.

| | `(name)` anchor | `mutate.foreach` |
| :--- | :--- | :--- |
| New value | the same literal for every element | computed per element, from `element` |
| Expressed as | one fragment with an anchored key | a loop with a body per iteration |
| Reach | one list, matched by key | any list a JMESPath expression can name, including nested ones |

The anchor is the lighter tool and reads better when it fits — "every container gets `imagePullPolicy: IfNotPresent`" is clearer as an anchor than as a loop. Reach for `foreach` when the patch needs to *see* the element it is patching.

`foreach` also reaches lists the anchor cannot address conveniently. `request.object.spec.initContainers`, `request.object.spec.template.spec.containers` on a Deployment, or a nested list inside each container — any of these is just a different `list` expression. Multiple entries under `foreach` run in order, which is how one rule covers both `containers` and `initContainers`:

```yaml
mutate:
  foreach:
    - list: "request.object.spec.containers"
      patchStrategicMerge: { ... }
    - list: "request.object.spec.initContainers"
      patchStrategicMerge: { ... }
```

> [!NOTE]
> A `foreach` entry may use `patchesJson6902` instead of `patchStrategicMerge`, which is occasionally the better fit — an RFC 6902 patch can address `/spec/containers/0/env/-` directly and does not need the merge-key dance. Section 080 covers the operation set and the escaping rules; everything there applies unchanged inside a `foreach`.

## What the loop does not give you

Two limits worth knowing before you build on this.

**There is no index.** `element` is the item; there is no `elementIndex`-style variable exposed to a mutate `foreach` body. Patches that genuinely need to know "this is the first container" are better expressed with `patchesJson6902` against an explicit path than with a loop.

**An empty list is not an error.** If `list` resolves to nothing — no `initContainers`, say — the entry simply performs no iterations. That is convenient, and it is also why a `foreach` that silently does nothing is usually a wrong `list` expression rather than a broken patch. Check what the expression resolves to before suspecting the body.

## Section recap

`mutate.foreach` runs a patch once per element of a list, with the element bound to `element`, which is what makes a per-element computed change possible at all. The `(name)` anchor remains the better tool when every element gets the same literal value. Inside the loop, a strategic-merge patch still needs the merge key — usually `name: "{{ element.name }}"` — to identify which element it applies to.
