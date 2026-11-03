# Part 1: Assertion Trees

## What an assertion tree is

An assertion tree is the body of a `validate.assert` rule. Kyverno added this subrule in version 1.13. You write the tree as YAML under a key named `object`, which stands for the resource that Kyverno is checking.

```yaml
validate:
  message: "The default service account must not be used."
  assert:
    object:
      spec:
        (serviceAccountName == 'default'): false
```

Read the tree from the top. `object` selects the resource. `spec` selects the `spec` field of the resource. The last line is a key in parentheses: it is an expression, not a field name.

Kyverno evaluates `serviceAccountName == 'default'` against the current node (here `spec`). The result is `true` or `false`. Kyverno then compares that result with the value on the right of the colon. The rule passes when they are equal.

Besides `object`, a tree can also read `oldObject` (the resource before an update), `operation`, `namespaceLabels` and `admissionInfo`.

## Projections and leaves

A key in the tree is a *projection*. It selects a part of the data, and the selected part becomes the current node for everything below it. There are two kinds of key:

- A plain key such as `spec` selects the field with that name. If the field does not exist, the check fails.
- A key in parentheses such as `(serviceAccountName == 'default')` is a JMESPath expression. The result of the expression becomes the current node.

All comparisons happen in the leaves of the tree. A leaf is a value that has no children: a string, a number, a boolean, or `null`. The tree above has one leaf, `false`.

Because an expression can return any value, you can compute before you compare:

```yaml
object:
  spec:
    (replicas * `2`): 6
```

A number inside an expression is written between backticks, for example `` `2` ``. A string is written between single quotes, as in `'default'`.

## Checking every item in a list

Pods have a list of `containers`. If you write `containers` as a plain key, the next node receives the whole list, not one container. To check each container, add the `~.` modifier in front of the key:

```yaml
object:
  spec:
    ~.containers:
      (ends_with(image, ':latest')): false
```

Kyverno takes each element of `containers` in turn. For each element, it evaluates `ends_with(image, ':latest')` and expects `false`. One container that fails produces one error, and the Pod is rejected.

The modifier can also name the index of the current element. `~i.containers` binds the position of the element (0, 1, 2, and so on) to the name `i`, and children can read it as `$i`. When the modifier is used on a map, the name receives the key of each entry.

## Named bindings

Sometimes a child needs a value that a parent computed. Add `->name` to the end of a key to store the result of that node, and read it in a descendant as `$name`:

```yaml
object:
  spec:
    (length(containers))->count:
      ($count <= `2`): true
```

A binding is visible to the node that defines it and to everything below that node. It is not visible to siblings or to parents. If a child defines the same name again, the new value applies only below that child.

## The order of checks

Do not rely on any order between the keys of one node. Kyverno does not promise that it evaluates `serviceAccountName` before `containers`, so a check must never need an earlier check to have run. Kyverno reports the failures from the whole tree. A rejection can therefore list several problems at once.

Data flows in one direction only: from the parent to its children. The parent selects or computes a value, the children compare against it. If one check needs the result of another, put the second check below the first and use a binding.

A list written as a YAML list, without `~.`, behaves differently from a mapping. Kyverno compares it position by position and requires that the resource has the same number of items. Use `~.` whenever you mean "every item".

## How `assert` differs from `pattern`

| | `pattern` | `assert` |
| :--- | :--- | :--- |
| Shape | The resource you expect, with wildcards | A tree of projections and expected results |
| Computation | None. Values are compared as they are | JMESPath expressions in parentheses |
| Lists | A single element describes every item | `~.` selects every item |
| Missing fields | Controlled with anchors | A plain key that is missing fails; an expression returns `null` |
| Best for | "The resource must look like this" | "This calculated value must be true" |

Use `pattern` when the requirement is easy to draw as a resource. Use `assert` when you need a function such as `ends_with`, a length, a sum, or a comparison between two fields.

> [!NOTE]
> Kyverno generates matching rules for Deployments, StatefulSets and other Pod controllers when an `assert` rule matches `Pod`. Test the Pod form first. It is the shape you write the tree against.

<!-- astrona:playground:renew -->
> [!TIP]
> **Try it — reject the default service account and the `latest` tag**
>
> Save this as `assert-pods.yaml`:
>
> ```yaml
> apiVersion: kyverno.io/v1
> kind: ClusterPolicy
> metadata:
>   name: assert-pods
> spec:
>   validationFailureAction: Enforce
>   background: false
>   rules:
>     - name: no-default-sa-no-latest
>       match:
>         any:
>           - resources:
>               kinds: ["Pod"]
>               namespaces: ["demo"]
>       validate:
>         message: "Pods must not use the default service account or a :latest image."
>         assert:
>           object:
>             spec:
>               (serviceAccountName == 'default'): false
>               ~.containers:
>                 (ends_with(image, ':latest')): false
> ```
>
> Apply it and test two Pods:
>
> ```sh
> kubectl create namespace demo
> kubectl apply -f assert-pods.yaml
> kubectl run ok --image=nginx:1.27 --restart=Never -n demo
> kubectl run bad --image=nginx:latest --restart=Never -n demo
> ```
>
> The first Pod is created. The second is rejected by the admission webhook, and the error message contains your `message` text. The error also points at the path of the failed check, for example the container index, so you can see which item broke the rule.
>
> Now remove `~.` from the `containers` key and apply the policy again. Run the same two Pods. Because the node now receives the whole list, the expression `ends_with(image, ':latest')` no longer runs against one container, and the result is an error or a failed check instead of a clean pass. This shows why `~.` matters.

## Common pitfalls

> [!WARNING]
> **Common pitfalls**
>
> - **Forgetting `~.` on a list.** Without it the children receive the whole list, not each item.
> - **Writing a field name in parentheses by mistake.** `(image)` is an expression that returns the value of `image`. Use a plain key when you only want to select a field.
> - **Depending on the order of sibling keys.** Kyverno does not guarantee one. Put dependent checks below the check they need, with a binding.
> - **Using a bare `null` or an unquoted number in an expression.** Write `` `null` `` and `` `3` `` between backticks, and strings between single quotes.
> - **Expecting a missing field to pass.** A plain key that does not exist fails the check. Use an expression, which returns `null`, when the field is optional.
> - **Checking only the Pod form.** An image without a tag also means `latest`, but `ends_with(image, ':latest')` does not catch it. Write exactly what you need to reject.
