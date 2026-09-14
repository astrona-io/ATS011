# Part 1: JMESPath, Variables & Built-in Context

## The `{{ }}` syntax

You've already used `{{ }}` in passing, in earlier sections' `message` fields and `preconditions`, without a full explanation. Now it gets one: `{{ expr }}` tells Kyverno "evaluate `expr` as a JMESPath expression against the rule's current context, and substitute the result as a string (or, in a numeric/boolean comparison, as its native type)." The context being queried isn't just the incoming resource — it's a growing JSON document Kyverno assembles as the rule runs, starting with the admission request and gaining one more entry for every `context` block you add (Part 2 covers adding to it yourself with `context.apiCall`).

A plain top-level reference doesn't strictly need the braces in every field — some fields (like a `preconditions` `key`) accept a bare JMESPath string. But the moment a variable sits *inside* a larger string — a sentence in a `message`, a value nested inside a YAML string — you need the double-brace form so Kyverno knows where the expression starts and ends:

```yaml
message: >-
  Image "{{ request.object.spec.containers[0].image }}" is missing a
  digest or an approved tag.
```

If you ever need a literal `{{ }}` in your output — because some *other* system also uses that syntax — escape it with a leading backslash (`\{{ }}`) to stop Kyverno from trying to resolve it.

## Where `{{ }}` is legal — and the one place it categorically isn't

Variables are accepted almost everywhere a rule's *behavior* is decided:

- `validate.message`
- `validate.pattern` and `validate.anyPattern` values
- `validate.deny.conditions` (`key` and `value`)
- `preconditions.all`/`any` (`key` and `value`)
- `mutate.patchStrategicMerge` and `mutate.patchesJson6902` (values — not the `path` key of a JSON patch, which must stay static)
- `generate` resource data
- `context.apiCall.urlPath` and `context.apiCall.data` (Part 2)

There is exactly one place they are refused outright: **`match` and `exclude`**. Section 020 already established this and confirmed it against a live cluster: a `match`/`exclude` block cannot hold a `{{ }}` expression, full stop. Kyverno's own documentation states the reason plainly — *"variable substitution is not currently supported in `match` or `exclude` statements"* — so that the API server can decide which resources even need a rule evaluated by inspecting static YAML, without first having to build a request context and run JMESPath. `match`/`exclude` answers "which resources," using only kind/namespace/name/label vocabulary; everything past that — an actual field value, a live API lookup, a comparison — has to happen inside the rule body, where variables are welcome.

> [!NOTE]
> It is easy to write a rule that *looks* like it's varying `match` and have it silently do nothing of the sort. `match.resources.namespaces: ["{{ request.namespace }}"]` is not an error — Kyverno accepts it as YAML — but the braces are treated as a literal namespace-glob string, not a variable, so the rule matches a namespace literally named `{{ request.namespace }}` (which doesn't exist) and therefore never fires on anything. If a rule you expect to match isn't matching at all, and there's a `{{ }}` anywhere in its `match`/`exclude` block, that's the first thing to check.

## JMESPath, as Kyverno actually uses it

Kyverno embeds a standard JMESPath engine, with a handful of extra functions layered on top for Kubernetes-shaped data. You don't need the full JMESPath specification to be productive — three patterns cover the overwhelming majority of real policies:

**Plain field access**, dot-separated, identical to how you'd describe the field in English:

```
request.object.metadata.name
request.object.spec.containers[0].image
request.object.metadata.labels.team
```

**Array indexing and filters.** `[0]` picks the first element positionally; `[?expression]` filters a list to elements matching a boolean expression, and is how you ask "does *any* container use this image" without knowing how many containers there are or which position they're in:

```
request.object.spec.containers[?image == 'nginx:latest']
```

That expression returns an array (empty if nothing matched); a common idiom is wrapping it in `length(@)` to get a count, or piping it (`|`) into `[0]` to get just the first match.

**`length(@)`**, Kyverno's most-used aggregate function, turns an array into a count — the exact tool Part 2 uses to turn a list of Pods returned by the Kubernetes API into a number a `deny` condition can compare against.

## Built-in request variables

Every admission request Kyverno evaluates carries a fixed set of top-level fields, available in every rule without any `context` block at all:

| Variable | Holds |
| --- | --- |
| `request.object` | The incoming resource, exactly as submitted (on CREATE and UPDATE) |
| `request.oldObject` | The resource's previous version — **only present on UPDATE and DELETE**, never on CREATE |
| `request.operation` | `CREATE`, `UPDATE`, `DELETE`, or `CONNECT` |
| `request.namespace` | The namespace of the resource being admitted |
| `request.userInfo.username` | The identity that made the request |

`request.oldObject` deserves a moment of care, because reaching for it on the wrong operation is a common mistake: on a CREATE, there is no "old" version, so `request.oldObject` simply doesn't exist in the context yet. A rule that references it unconditionally on a CREATE-triggering match will either resolve to an empty value or, depending on how it's used, fail outright — which is exactly why comparisons involving `request.oldObject` are almost always paired with a `request.operation == 'UPDATE'` precondition first.

### Try it: proving oldObject, operation, and userInfo are real

This was verified directly against a `kind` cluster running Kyverno v1.19.1. The policy denies an UPDATE to any ConfigMap that was previously labeled `locked: "true"`, and its message pulls three different built-in variables into one sentence:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: block-locked-cm-edit
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: block-locked-edit
      match:
        any:
          - resources:
              kinds:
                - ConfigMap
      preconditions:
        all:
          - key: "{{ request.operation }}"
            operator: Equals
            value: "UPDATE"
          - key: "{{ request.oldObject.metadata.labels.locked || '' }}"
            operator: Equals
            value: "true"
      validate:
        message: >-
          ConfigMap was locked ({{ request.oldObject.metadata.labels.locked }})
          before this UPDATE by user {{ request.userInfo.username }}; locked
          ConfigMaps cannot be modified.
        deny: {}
```

Run it as three commands and watch the same object go from freely editable to
frozen, without the policy changing at all in between.

> [!TIP]
> **Try it — three built-in variables in one message**
>
> ```sh
> kubectl apply -f locked-cm-policy.yaml
> kubectl create configmap locked-cm --from-literal=x=1
> kubectl label configmap locked-cm locked=true
> kubectl label configmap locked-cm x=2 --overwrite
> ```
>
> Expect something like:
>
> ```text
> configmap/locked-cm created
> configmap/locked-cm labeled
>
> resource ConfigMap/default/locked-cm was blocked due to the following policies
>
> block-locked-cm-edit:
>   block-locked-edit: ConfigMap was locked (true) before this UPDATE by user kubernetes-admin; locked ConfigMaps cannot be modified.
> ```
>
> Three things to notice. The CREATE passed: a CREATE has no `oldObject`, so the
> second precondition could not be true. Adding the `locked` label was itself an
> UPDATE and it passed too — because at the moment that request was evaluated,
> `oldObject` was the *unlabelled* version. Only the third command, the first
> UPDATE whose `oldObject` already carries the label, is denied. And the username
> in the message is whoever your kubeconfig authenticates as; `kubernetes-admin`
> is what a `kind` cluster's default admin context reports.

The `|| ''` in the second precondition's `key` is a JMESPath default: on a request where `request.oldObject` genuinely has no `locked` label, the raw expression would resolve to `null`, and comparing `null` against the literal string `"true"` would simply and correctly evaluate to false — the `|| ''` is defensive style, not strictly required here, but it's a habit worth having whenever a JMESPath path might legitimately be absent, since a missing intermediate key means the whole expression comes back empty rather than raising an error.

The rejection message resolved every one of `request.oldObject.metadata.labels.locked`, `request.userInfo.username`, and `request.operation` correctly against a live request — this isn't a mocked example.

## Where does JMESPath data actually come from?

Everything covered in this part comes for free with every admission request — no extra configuration, no extra permissions, no network call. It's the built-in shape of the object Kyverno already has in hand. Part 2 covers the mechanism for pulling in data Kyverno does *not* already have: another resource's live state, fetched from the Kubernetes API at the moment the rule runs.
