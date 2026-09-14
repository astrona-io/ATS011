# Part 2: Pointer Escaping and Missing Paths

Part 1 built a working `patchesJson6902` rule and left two things unexamined: what happens when a key name contains the very character a JSON Pointer uses as its separator, and what each operation does when the location you named is not there. Both are where this rule type stops being forgiving.

## When a key name contains a slash

Kubernetes annotation and label keys are routinely namespaced with a `/`:

```yaml
metadata:
  annotations:
    policy.example.com/reviewed: "true"
    legacy/unmanaged-scanner: "true"
```

A JSON Pointer also uses `/` — as its path separator. So writing this is wrong:

```yaml
path: /metadata/annotations/policy.example.com/reviewed   # WRONG
```

That pointer reads as four segments — `metadata`, `annotations`, `policy.example.com`, `reviewed` — and asks for a `reviewed` key inside an object stored under a `policy.example.com` key. No such structure exists.

RFC 6901 solves this with two escape sequences, and only two:

| In the key | Write in the pointer |
| :--- | :--- |
| `/` | `~1` |
| `~` | `~0` |

So the correct pointer is:

```yaml
path: /metadata/annotations/policy.example.com~1reviewed
```

The order matters when both appear: unescape `~1` to `/` first, then `~0` to `~`. In practice you will almost never hit a `~` in a Kubernetes key, but `~1` you will hit constantly — this is the single most common reason a `patchesJson6902` rule "does nothing" or errors on a path that obviously exists.

> [!NOTE]
> Nothing else gets escaped. Dots, dashes, and colons in a key (`policy.example.com`, `kubernetes.io/arch`, `node-role`) are ordinary characters to a JSON Pointer — only `/` and `~` are special. A pointer is a literal walk, not a pattern language, so there is nothing else for it to misread.

## What each operation does when the path is missing

This is where `patchesJson6902` stops being forgiving, and the three operations behave differently from one another. All three were verified directly on Kyverno v1.19.1 while building this course.

### `add` against a missing target — succeeds, and creates the parent

```yaml
mutate:
  patchesJson6902: |-
    - op: add
      path: /metadata/annotations/policy.example.com~1reviewed
      value: "true"
```

Two properties make `add` the easy one, and they are worth seeing in a single
run: it creates the parent map when it is missing, and it overwrites the value
when the key is already there.

> [!TIP]
> **Try it — `add` copes with both absence and presence**
>
> ```sh
> kubectl create -f - <<'EOF'
> apiVersion: v1
> kind: Pod
> metadata:
>   name: probe-d
> spec:
>   containers: [{name: app, image: nginx}]
> EOF
> kubectl get pod probe-d -o jsonpath='{.metadata.annotations}'
>
> kubectl create -f - <<'EOF'
> apiVersion: v1
> kind: Pod
> metadata:
>   name: probe-e
>   annotations:
>     policy.example.com/reviewed: "false"
> spec:
>   containers: [{name: app, image: nginx}]
> EOF
> kubectl get pod probe-e -o jsonpath='{.metadata.annotations}'
> ```
>
> Expect something like:
>
> ```text
> pod/probe-d created
> {"policy.example.com/reviewed":"true"}
>
> pod/probe-e created
> {"policy.example.com/reviewed":"true"}
> ```
>
> The first Pod had no `annotations` map at all and one was created. The second
> had the key already set to `"false"` and it was replaced. (`kubectl create`
> rather than `apply` here keeps the output clean — `apply` adds a
> `last-applied-configuration` annotation of its own that clutters the read-back.)

Practical consequence: an unconditional `add` is safe to run on every resource. You never need a precondition merely to protect it from a resource that already has the field.

### `remove` against a missing target — silent no-op on this version

```yaml
mutate:
  patchesJson6902: |-
    - op: remove
      path: /metadata/annotations/legacy~1unmanaged-scanner
```

Apply that rule on its own and probe it from both sides: a Pod that never carried
the annotation, and one that does. Watch whether the first is admitted, and
whether anything *other* than the targeted key survives on the second.

> [!TIP]
> **Try it — `remove` finds nothing and says nothing**
>
> ```sh
> kubectl run probe-a --image=nginx --restart=Never
>
> kubectl apply -f - <<'EOF'
> apiVersion: v1
> kind: Pod
> metadata:
>   name: probe-b
>   annotations:
>     legacy/unmanaged-scanner: "true"
>     team: platform
> spec:
>   containers: [{name: app, image: nginx}]
> EOF
> kubectl get pod probe-b -o jsonpath='{.metadata.annotations.legacy/unmanaged-scanner}'
> kubectl get pod probe-b -o jsonpath='{.metadata.annotations.team}'
> ```
>
> Expect something like:
>
> ```text
> pod/probe-a created
> pod/probe-b created
>
> platform
> ```
>
> `probe-a` never had the annotation and was admitted with no complaint. On
> `probe-b` the annotation was removed — the first read-back is empty — while the
> unrelated `team` annotation survived. Note that the `jsonpath` query spells the
> key with a plain `/`: JSON Pointer's `~1` escaping does not apply here, which is
> a small but real source of confusion when you are switching between the two.

### `replace` against a missing target — rejects the entire request

```yaml
mutate:
  patchesJson6902: |-
    - op: replace
      path: /metadata/annotations/legacy~1unmanaged-scanner
      value: "rewritten"
```

Swap the previous policy for this one — identical path, one different keyword —
and submit the same kind of Pod that `remove` admitted a moment ago. This is the
comparison the whole section is built around, so run it rather than reading it.

> [!TIP]
> **Try it — `replace` takes the whole request down with it**
>
> ```sh
> kubectl run probe-c --image=nginx --restart=Never
> ```
>
> Expect something like:
>
> ```text
> Error from server: admission webhook "mutate.kyverno.svc-fail" denied the request: mutation policy probe-replace error: failed to apply policy probe-replace rules [unguarded-replace: failed to patch resource: replace operation does not apply: doc is missing path: /metadata/annotations/legacy~1unmanaged-scanner: missing value]
> ```
>
> Same missing path, same Pod shape, and this time nothing is created at all.
> Delete this policy before moving on — while it is applied, every Pod in the
> cluster lacking that annotation is unschedulable.

Read that error carefully, because it is the shape of every JSON Patch failure you will debug: the webhook name tells you it was the **mutation** webhook, `failed to patch resource` tells you the policy matched and the engine got as far as applying operations, and the trailing clause names the exact pointer that didn't resolve. You will see two wordings there depending on *where* the walk broke — `doc is missing path:` when an intermediate segment is absent (the Pod has no `annotations` map at all), and `doc is missing key:` when the map exists but the final key is not in it. Both mean the same thing for your purposes: that pointer does not resolve on this resource.

## Section recap

RFC 6901 has exactly two escapes — `~1` for a literal `/` and `~0` for a literal `~` — and forgetting the first is the most common reason a pointer silently addresses nothing. The three operations then diverge sharply on a missing path: `add` succeeds and creates what is absent, `remove` is a silent no-op on this version, and `replace` rejects the entire admission request. Part 3 turns that divergence into a rule you can write without having to remember which of the three you are using.
