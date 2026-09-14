# Part 1: RFC 6902 Operations and Pointer Paths

## The thing strategic merge cannot say

Start with a concrete problem. A Pod arrives carrying an annotation you want gone:

```yaml
metadata:
  annotations:
    legacy/unmanaged-scanner: "true"
```

With `patchStrategicMerge` you describe the shape you want the resource to have. So how do you describe the *absence* of a key? You cannot write `legacy/unmanaged-scanner:` and expect deletion — an empty value is a value. Strategic merge does have a deletion directive (`$patch: delete`), but it is awkward, only applies in specific list and map contexts, and is not what most policy authors reach for. There is simply no natural way in the merge vocabulary to say "this key should not be here."

Two more things it struggles with:

* **"The first container, whichever one that is."** Strategic merge reconciles lists by a *merge key* — for containers that key is `name`. You can say "the container named `app`" or, with the `(name)` anchor from Section 040, "every container." You cannot say "index 0."
* **"Append one more entry to this list."** Again, merge-by-key: your fragment either matches an existing element by its key and merges into it, or it becomes a new element. Expressing "add this to the end, and leave everything already there alone" through a merge key is indirect at best.

Each of those is a one-line JSON Patch operation.

## Not the same thing: `kyverno-json`

Before going further, one disambiguation that costs nothing now and saves confusion later.

Search for "Kyverno JSON" and you will find **`kyverno-json`** — a separate project in the Kyverno GitHub organisation, with its own binary of that name. It is not what this module teaches, and the two are unrelated beyond sharing a policy engine.

| | `mutate.patchesJson6902` *(this module)* | `kyverno-json` *(the other project)* |
| :--- | :--- | :--- |
| What it is | a rule body inside a `ClusterPolicy` | a standalone CLI, web service, or Go library |
| What it acts on | a Kubernetes resource passing through admission | any JSON or YAML payload — Terraform plans, Dockerfiles, cloud configuration, authorization requests |
| Needs a cluster | yes, it runs in the admission path | no, it runs anywhere |
| What "JSON" refers to | the RFC 6902 **patch format** | the **payload format** being validated |
| Maturity | stable, part of Kyverno proper | early development; the project warns that changes may not be backward compatible |

The collision is purely one of naming. This module's subject is a *patch format* — RFC 6902, the thing that describes a change as a list of operations. `kyverno-json`'s subject is the *kind of data* Kyverno's engine can be pointed at, extending it past Kubernetes resources entirely.

> [!NOTE]
> This matters for exam preparation because at least one widely-circulated KCA study guide maps the "JSON Patches" competency to `kyverno-json` rather than to `patchesJson6902`. The official curriculum lists only the bare heading, so neither reading can be proven from it — but "JSON Patches" sits among ten other *rule-authoring* competencies, which makes `patchesJson6902` the reading this course takes. `kyverno-json` is a tool you point at files from a terminal, which places it much closer to the separate Kyverno CLI domain. Know that both exist and what each one is, and a question framed either way will not catch you out.

## The operation set

RFC 6902 defines six operations. A `patchesJson6902` block is a YAML list of them, applied **in the order written**:

| `op` | What it does |
| :--- | :--- |
| `add` | Insert a value at the path. On an array index, inserts *before* that element; on `/-`, appends. On an object member that already exists, **replaces** its value. |
| `remove` | Delete the value at the path. |
| `replace` | Overwrite the value at the path. Conceptually a `remove` followed by an `add`. |
| `copy` | Duplicate the value at `from` to the path. |
| `move` | Relocate the value at `from` to the path. |
| `test` | Assert the value at the path equals `value`. If it does not, the whole patch fails. |

In Kyverno policies you will overwhelmingly use the first three. `copy` and `move` occasionally appear when relocating a label; `test` is rarely used in Kyverno because `preconditions` already expresses "only run this rule when the resource looks like X," and does so with much better error reporting.

## Reading a JSON Pointer path

The `path` field is an RFC 6901 **JSON Pointer**: a `/`-separated walk down the document from its root, starting with a leading `/`. It is not JMESPath, and it is not a Kubernetes field selector — it has no filters, no wildcards, and no expressions. Each segment is either an object key or, inside an array, a numeric index.

Given this Pod:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: demo
spec:
  containers:
    - name: app
      image: nginx
      env:
        - name: EXISTING
          value: "one"
```

these pointers address:

| Pointer | Addresses |
| :--- | :--- |
| `/metadata/name` | the string `demo` |
| `/spec/containers` | the whole containers array |
| `/spec/containers/0` | the first container object |
| `/spec/containers/0/image` | the string `nginx` |
| `/spec/containers/0/env/0/value` | the string `one` |
| `/spec/containers/0/env/-` | the position *after* the last `env` element |

That final one — a bare `-` where an index would go — is RFC 6902's append token. It is only meaningful as the last segment of an `add` (or the target of a `copy`/`move`); it means "one past the end," which is exactly where a new element should go.

> [!NOTE]
> Array indices in a JSON Pointer are positions in the document as it exists *at that moment in the patch*. If your patch list has an `add` that inserts at `/spec/containers/0` followed by another operation addressing `/spec/containers/1`, the second operation sees the array after the first one ran. Ordering is not cosmetic.

## A rule that appends an environment variable

Here is the whole thing — a `ClusterPolicy` with one `mutate.patchesJson6902` rule that stamps an environment variable onto the first container of every Pod in the cluster:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: inject-env-json-patch
spec:
  rules:
    - name: add-env-var
      match:
        any:
          - resources:
              kinds:
                - Pod
      mutate:
        patchesJson6902: |-
          - op: add
            path: /spec/containers/0/env/-
            value:
              name: INJECTED_BY_POLICY
              value: "true"
```

Three details worth naming before you run it:

* **`patchesJson6902` takes a string, not structured YAML.** Note the `|-` block scalar. Kyverno parses that string as its own YAML (or JSON) document containing the operation list. Forgetting the `|-` and writing the list inline as native YAML is a common first mistake; the CRD schema expects a string there.
* **`op: add` with `/-`, not `replace`.** `replace` requires you to name an index that already exists, which means knowing how many `env` entries the incoming Pod had. `add` with the append token needs to know nothing.
* **`value` is the complete element** being inserted — here a full `{name, value}` env entry, not just a scalar.

Apply it:

```bash
kubectl apply -f policy.yaml
# clusterpolicy.kyverno.io/inject-env-json-patch created

kubectl get clusterpolicy inject-env-json-patch
# NAME                    ADMISSION   BACKGROUND   READY   AGE   MESSAGE
# inject-env-json-patch   true        true         True    5s    Ready
```

(You will also see the familiar `kyverno.io/v1 ClusterPolicy is deprecated` warning — expected on v1.19.1 and safe to ignore.)

## The two cases that matter

The interesting question is not whether this works on a Pod that already has
`env` — it is what happens on a Pod that does not. Submit both and read back what
the cluster stored, because nothing in the admission response tells you a patch
happened at all.

> [!TIP]
> **Try it — append to a list that may not exist**
>
> ```sh
> kubectl apply -f - <<'EOF'
> apiVersion: v1
> kind: Pod
> metadata:
>   name: has-env
> spec:
>   containers:
>     - name: app
>       image: nginx
>       env:
>         - name: EXISTING
>           value: "one"
> EOF
> kubectl get pod has-env -o jsonpath='{.spec.containers[0].env}'
>
> kubectl run no-env --image=nginx --restart=Never
> kubectl get pod no-env -o jsonpath='{.spec.containers[0].env}'
> ```
>
> Expect something like:
>
> ```text
> pod/has-env created
> [{"name":"EXISTING","value":"one"},{"name":"INJECTED_BY_POLICY","value":"true"}]
>
> pod/no-env created
> [{"name":"INJECTED_BY_POLICY","value":"true"}]
> ```
>
> `EXISTING` survived and the new entry landed after it — that is what "append"
> should mean. And the second Pod, which had no `env` array at all, came out with
> one containing exactly your entry.

> [!NOTE]
> That second result is worth pausing on, because it contradicts what a careful reading of RFC 6902 would lead you to expect. The spec says the *parent* of the target location must exist — and on `no-env`, `/spec/containers/0/env` does not exist at all, so `/spec/containers/0/env/-` has no parent array to append to. A strict implementation would be entitled to fail. It was verified directly on Kyverno v1.19.1 while building this course that it does not: the `env` array is created and your value becomes its sole element. Convenient, and it is what makes this one rule cover both Pod shapes — but treat it as behaviour observed on this version rather than a guarantee you can carry to any JSON Patch library.

Clean up when you are done experimenting:

```bash
kubectl delete pod has-env no-env --ignore-not-found
```

## What you now know

`patchesJson6902` trades the shape-describing comfort of strategic merge for exact addressing: an ordered operation list, each aimed at one JSON Pointer location. You can append with `/-`, target an array element by index, and reach fields that strategic merge has no vocabulary for. Part 2 deals with the two things that bite next — key names containing a literal `/`, and what each operation does when the path you named isn't there.
