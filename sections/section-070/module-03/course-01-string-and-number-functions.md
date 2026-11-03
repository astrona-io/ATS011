# Part 1: String and number functions

## How a Kyverno function is called

A Kyverno function is called like any JMESPath function, inside `{{ }}`:

```yaml
key: "{{ to_upper(request.object.metadata.labels.team) }}"
```

Three rules cover almost every mistake people make with them.

**The arguments are positional and the order matters.** `regex_match` takes the pattern first and the text second. `split` takes the text first and the separator second. The order is not consistent across functions, so check it for each one.

**String literals use single quotes, and number literals use backticks.** `'platform'` is a string. `` `2` `` is a number. A bare `2` is not a valid JMESPath literal. Because the whole expression is already inside a double-quoted YAML string, single quotes inside it need no escaping.

**Annotation and label values are strings.** An annotation `retries: "3"` is the string `"3"`. A function that wants a number, such as `subtract`, or a comparison that should be numeric, needs `to_number(...)` first.

A missing field makes a function receive `null`, which most functions reject with an error. Giving the path a fallback with `||` turns a missing value into something the function can use:

```yaml
"{{ to_upper(request.object.metadata.labels.team || 'none') }}"
```

<!-- astrona:playground:renew -->

## A probe policy for trying functions

Reading about a function is slower than watching it run. This policy denies every ConfigMap created in the `fn-lab` namespace and puts a computed value into the denial message, which turns the rejection into a print statement:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: probe
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: show
      match:
        any:
          - resources:
              kinds: ["ConfigMap"]
              namespaces: ["fn-lab"]
      validate:
        message: "RESULT={{ to_upper(request.object.data.word) }}"
        deny:
          conditions:
            all:
              - key: "a"
                operator: Equals
                value: "a"
```

Change the expression in `message` to try any function in this module. Create a namespace first with `kubectl create ns fn-lab`, then provoke the policy with a ConfigMap that carries the input in `data.word`:

```sh
kubectl create configmap c1 -n fn-lab --from-literal=word=hello
```

> [!TIP]
> **Try it — read a function result in a denial message**
>
> ```sh
> kubectl apply -f probe.yaml
> kubectl create ns fn-lab
> kubectl create configmap c1 -n fn-lab --from-literal=word=hello
> ```
>
> The create is rejected, which is the point. The error text contains the message
> with the expression already evaluated: the word `hello` in upper case. Change
> the policy and create a ConfigMap with another name to try the next function.

The rest of this part uses the same shape. Each example is an expression you can paste into the `message` of the probe.

## Regular expressions

`regex_match(pattern, text)` returns `true` when the text matches the pattern. The pattern is the first argument.

```yaml
key: "{{ regex_match('^[a-z]+-[0-9][0-9]$', request.object.metadata.name) }}"
operator: Equals
value: false
```

That condition is true, and the `deny` fires, when the name does not look like `web-01`. A denial that fires on a match failing is the usual way to write a naming rule. The second argument may be a string or a number.

The pattern is a Go regular expression and is not anchored on its own. Without `^` and `$`, `regex_match('[0-9]+', 'abc1')` is true, because a digit appears somewhere. Anchor the pattern when the whole value must match.

`regex_replace_all(pattern, text, replacement)` replaces every match. The replacement may refer to a captured group as `${1}`. The documentation shows `regex_replace_all('([0-9])([0-9])', 'hello im 42 months old', '${1}1')` giving `hello im 41 months old`.

`replace_all(text, old, new)` replaces every literal occurrence and involves no regular expression. `replace(text, old, new, n)` does the same but stops after `n` replacements, and `n` is a number literal such as `` `2` ``. Prefer `replace_all` when you do not need a pattern, because a literal is harder to get wrong.

## Case, splitting, trimming and shortening

`to_upper(text)` and `to_lower(text)` change case and return a string. Use them to compare values without caring about case, for instance an environment label that people write as `Prod`, `prod` and `PROD`.

`equal_fold(a, b)` returns `true` when two strings are equal ignoring case. When the only question is whether two strings are the same, it is shorter than lowering both sides.

`split(text, separator)` returns an array of strings. Index into the result to take one piece:

```yaml
key: "{{ split(request.object.metadata.annotations.owner || '', '/')[0] }}"
```

For `platform/web` that is `platform`. For a missing annotation, the fallback `''` splits into a single empty string, so index `0` is empty rather than an error.

`trim(text, cutset)` removes from both ends any of the characters listed in the second argument. The second argument is a set of characters, not a word. The documentation's examples show it: `trim('foocorpcom','mo')` gives `foocorpc`, `trim('foocorpcom','o')` gives `foocorpcom` because no `o` is at either end, and `trim('foocorpcom','mcof')` gives `rp`. To remove one specific prefix, `trim_prefix(text, prefix)` is the exact tool.

`truncate(text, n)` keeps the first `n` characters, with `n` as a number literal. `truncate('foobar', `3`)` gives `foo`. A common use is shortening a value to a length limit, for instance a build hash to twelve characters.

`compare(a, b)` returns the number `0` when the strings are equal, `-1` when the first sorts before the second, and `1` when it sorts after.

## Base64

`base64_encode(text)` and `base64_decode(text)` convert a string to and from base64.

```yaml
key: "{{ base64_decode(request.object.metadata.annotations.config || '') }}"
operator: NotEquals
value: ready
```

For the annotation value `cmVhZHk=` the decoded text is `ready`, so this condition is false and nothing is denied. The decode function is most useful with a `Secret`, whose `data` values are always base64. A rule that has to look at the real content of a Secret value decodes it first.

> [!TIP]
> **Try it — a round trip**
>
> Put `{{ base64_decode(base64_encode(request.object.data.word)) }}` in the probe
> message and create a ConfigMap with `word=hello`. The denial text shows `hello`
> again. Then try `{{ base64_encode(request.object.data.word) }}` alone and
> compare the output with `echo -n hello | base64`.

## Arithmetic

The arithmetic functions take two arguments and return the result:

| Function | Meaning |
| --- | --- |
| `add(a, b)` | a plus b |
| `subtract(a, b)` | a minus b |
| `multiply(a, b)` | a times b |
| `divide(a, b)` | a divided by b |
| `modulo(a, b)` | remainder of a divided by b |
| `round(n, digits)` | n rounded to `digits` decimal places |

They work on plain numbers, and also on Kubernetes quantities such as `200Mi` and durations such as `2h`. `sum(array)` adds up an array of numbers, quantities or durations of the same kind, and needs at least one element.

The fact that matters in practice is the type. A number read from an annotation is a string, so convert it:

```yaml
key: "{{ subtract(to_number(request.object.metadata.annotations.requested || '0'), to_number(request.object.metadata.annotations.used || '0')) }}"
operator: LessThan
value: 0
```

That condition fires when more is used than was requested. The `value: 0` is a YAML number, so the comparison is numeric.

> [!TIP]
> **Try it — string arithmetic versus number arithmetic**
>
> In the probe message, use `{{ subtract(to_number(request.object.data.a), to_number(request.object.data.b)) }}`
> with a ConfigMap that has `a=10` and `b=4`. The denial shows the difference.
> Then remove the `to_number` calls and read what changes in the error. The
> exact text depends on the version, so read it rather than guess it.

> [!WARNING]
> **Common pitfalls**
>
> - **Swapping the arguments of `regex_match`.** The pattern comes first and the text second.
> - **Forgetting that a regular expression is not anchored.** Add `^` and `$` when the whole value must match.
> - **Treating `trim` as removing a word.** The second argument is a set of characters, so `trim('foocorpcom','mo')` also strips an `m` and an `o`.
> - **Doing arithmetic on strings.** Wrap annotation and label values in `to_number(...)` first.
> - **Using a bare number as a literal.** Write `` `2` ``, with backticks, and write strings with single quotes.
> - **Passing a missing field to a function.** Add `|| ''` or another fallback so the function receives a value.
