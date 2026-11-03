# Part 2: Collections, time and encoding functions

<!-- astrona:playground:renew -->

## Maps and lists

`items(map, keyName, valueName)` turns a map into an array of objects. Each object has the two field names you chose:

```yaml
context:
  - name: labelPairs
    variable:
      jmesPath: "items(request.object.metadata.labels || `{}`, 'key', 'value')"
```

For labels `{team: apple, tier: web}` the variable holds one object per label, such as `{key: team, value: apple}`. That shape is what a `foreach` loop or a JMESPath filter such as `[?key == 'team']` needs, because a map cannot be iterated directly.

`object_from_lists(keys, values)` is the opposite. It takes an array of keys and an array of values and builds a map. A typical use is collecting the `name` and `value` of every environment variable across the containers of a Pod into one map that can be looked up by name:

```yaml
"{{ object_from_lists(request.object.spec.containers[].env[].name, request.object.spec.containers[].env[].value) }}"
```

`label_match(required, actual)` takes two maps and returns `true` when every key and value in the first map is present in the second. The second map may hold extra entries. This is the check for "the resource carries at least these labels":

```yaml
key: "{{ label_match(`{\"team\":\"platform\"}`, request.object.metadata.labels || `{}`) }}"
operator: Equals
value: false
```

The first argument here is a JSON object written as a JMESPath literal between backticks. Inside a YAML double-quoted string the inner double quotes must be escaped, which is easy to get wrong. When that gets unreadable, put the required labels in a `variable` context entry or a ConfigMap and pass the name instead.

`lookup(mapOrArray, keyOrIndex)` reads one entry from a map by a key held in a variable, or from an array by a number, and returns `null` when it is missing. A plain path such as `labels.team` cannot be written when the key itself is computed, and `lookup` is the answer there.

> [!TIP]
> **Try it — a map turned into a list**
>
> Create the probe policy from Part 1 again with the message
> `{{ items(request.object.data, 'key', 'value') }}`, then create a ConfigMap in
> `fn-lab` with two literals. The denial message lists both entries as key and
> value objects, one per key of the original map.

## Time

Time functions work on strings in RFC 3339 form, such as `2023-01-12T19:05:59Z`.

`time_now_utc()` returns the current time in UTC. `time_now()` returns the time as the node knows it and is not guaranteed to be in any particular zone, so prefer `time_now_utc()` when you compare.

`time_since(format, start, end)` returns the time between two timestamps as a duration string. An empty format means RFC 3339, and an empty end means now:

```yaml
key: "{{ time_since('', request.object.metadata.annotations.approved || '', '') }}"
operator: DurationGreaterThan
value: 24h
```

For an `approved` annotation set two days ago, the function returns a string such as `48h0m33s`, and the operator reads it as a duration and compares it with `24h`. The documentation shows `time_since('','2022-04-10T03:14:05-07:00','2022-04-11T03:14:05-07:00')` giving `24h0m0s`. A start that is empty or not a valid time is an error, so the annotation must exist.

Compare durations with the duration operators `DurationGreaterThan`, `DurationGreaterThanOrEquals`, `DurationLessThan` and `DurationLessThanOrEquals`. Using the plain numeric operators on a duration string is the wrong tool.

The other time functions you will meet:

| Function | What it does |
| --- | --- |
| `time_add(time, duration)` | adds a duration, for instance `time_add('2023-01-12T12:37:56-05:00','6h')` gives `2023-01-12T18:37:56-05:00` |
| `time_diff(start, end)` | duration from start to end, negative when end is earlier |
| `time_after(a, b)` | true when `a` is after `b` |
| `time_before(a, b)` | true when `a` is before `b` |
| `time_between(t, start, end)` | true when `t` falls between start and end |
| `time_parse(format, text)` | converts a time in another format to RFC 3339 |

The comparison functions return a boolean, so the usual use is `key: "{{ time_before(...) }}"` with `operator: Equals` and `value: true` or `false`.

> [!TIP]
> **Try it — how old is a timestamp**
>
> Use `{{ time_since('', request.object.data.stamp, '') }}` in the probe
> message. Create a ConfigMap in `fn-lab` with `--from-literal=stamp=` set to a
> timestamp from yesterday in RFC 3339 form. The denial shows the age as a
> duration string of a little over 24 hours.

## Versions and encoded documents

`semver_compare(version, constraint)` checks a version against a constraint and returns a boolean. The documentation shows `semver_compare('4.1.3','>=4.1.x')` giving `true` and `semver_compare('1.8.6','>1.0.0 <2.0.0')` giving `true`. Use it where a plain string comparison would sort `1.10.0` before `1.9.0`.

`parse_json(text)` turns a JSON string into a value that JMESPath can walk, and `parse_yaml(text)` does the same for YAML. They are the way to read a structured value that someone stored as a string in an annotation or a ConfigMap key.

## Choosing the right function

When a rule needs to look inside a value, decide first what kind of value it is. A name or code that must have a shape needs `regex_match`. A compound value such as `team/app` needs `split`. A secret-style value needs `base64_decode`. A number stored as text needs `to_number` and the arithmetic functions. An age needs `time_since`. A map that has to be searched needs `items`. Reaching for a function the first time is mostly a matter of recognising which of those six cases applies.

> [!WARNING]
> **Common pitfalls**
>
> - **Comparing a duration with a numeric operator.** Use `DurationGreaterThan` and its relatives for the result of `time_since`.
> - **Mixing time formats.** The time functions expect RFC 3339 unless you say otherwise with a format argument.
> - **Passing a missing annotation to a time function.** An empty or invalid time is an error, not a false.
> - **Forgetting the order of `label_match`.** The required labels come first and the actual labels second.
> - **Escaping quotes in an inline JSON literal.** Keep required values in a context variable when the escaping becomes unreadable.
> - **Assuming a function exists because it sounds natural.** Only the documented functions are available, so a typo is an error at evaluation time, not a silent false.

## Your mission: JMESPath Functions Lab

You can now write a rule that looks inside a value with a regular expression, splits it, decodes it, does arithmetic on it and measures its age. The mission asks you to write one policy with five rules, each of which uses a different function to accept or reject a Pod.

Pause the playground, start the lab, and submit your work as often as you like:

```sh
astrona stop ats-011-playground-0703
astrona run --git ssh://git@github.com/astrona-io/ATS011.git -c sections/section-070/module-03/labs/lab-01
astrona submit -c sections/section-070/module-03/labs/lab-01
```

When the lab passes, remove it and return to the playground:

```sh
astrona destroy ats-011-lab-073
astrona start ats-011-playground-0703
```
