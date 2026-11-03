# The Kyverno JMESPath Function Library

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS011/tree/main/sections/section-070/module-03/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS011.git -c sections/section-070/module-03/playground
> astrona destroy ats-011-playground-0703
> ```

The earlier modules of this section used JMESPath to pick values out of a request or out of a context entry: `request.object.spec.replicas`, `items[?name == 'x']`, `to_number(...)`. That is the standard language, and on its own it can only select and reshape.

Kyverno adds its own function library on top of it. The extra functions let a rule match a regular expression, change the case of a string, split a value on a separator, decode a base64 annotation, subtract two numbers, measure how long ago a timestamp was, and turn a map into a list. Most real policies that make a decision from the content of a value, rather than its mere presence, call one of these functions.

This module teaches the functions that appear most often in policies and in the exam, with the argument order and return type of each, and the traps around calling them.

## How this module is organised

1. **[Part 1 — String and number functions](./course-01-string-and-number-functions.md)** — how a function call is written, then `regex_match`, `regex_replace_all`, `replace_all`, `split`, `to_upper`, `to_lower`, `trim`, `truncate`, `compare`, `equal_fold`, `base64_encode`, `base64_decode`, and the arithmetic functions `add`, `subtract`, `multiply`, `divide`, `modulo`, `round` and `sum`.
2. **[Part 2 — Collections, time and encoding functions](./course-02-collections-time-and-encoding-functions.md)** — `items`, `object_from_lists`, `label_match`, `lookup`, the time functions `time_since`, `time_add`, `time_diff`, `time_before`, `time_after`, `time_between` and `time_now_utc`, `semver_compare`, `parse_json`, and the lab that puts several of them in one policy.

The module closes with a summary page and a mission, **JMESPath Functions Lab**, a graded lab that asks you to write and apply the policies from this module on a live cluster.

## Learning objectives

After this module you can:

- Write a Kyverno function call inside `{{ }}` with the correct argument order and quoting.
- Test a value against a regular expression with `regex_match` and say which argument is the pattern.
- Change, split, trim and shorten strings with `to_upper`, `to_lower`, `split`, `trim` and `truncate`.
- Decode a base64 value in a rule and compare it with an expected string.
- Do arithmetic on numbers pulled from annotations, and know that annotation values are strings until converted.
- Turn a map into a list of key and value objects with `items`, and test label subsets with `label_match`.
- Measure elapsed time with `time_since` and compare the result with a duration operator.

## Before you start

You need the earlier modules of this section: `{{ }}` variables, JMESPath basics, the `context` block, and `deny` conditions from the validation section.

The **playground** linked at the top of this page gives you a `kind` cluster with Kyverno v1.19.1 running and **no policies installed**. Once it is up, `kubectl` is already pointed at it — the context is `kind-astro-ats-011-playground-0703`. The `Try it` checkpoints in the parts below assume that environment is already running; they never repeat the startup command.
