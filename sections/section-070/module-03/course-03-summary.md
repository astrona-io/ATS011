# Summary

Kyverno extends JMESPath with a function library, and a rule calls those functions inside `{{ }}` like any other JMESPath function. The argument order differs between functions, strings use single quotes, numbers use backticks, and a missing field needs a fallback so the function does not receive `null`.

String functions let a rule judge the content of a value rather than its presence. `regex_match` tests a pattern, with the pattern first, and is not anchored unless the pattern says so. `split`, `trim`, `truncate`, `to_upper` and `to_lower` reshape a value so it can be compared. `base64_decode` reveals the real content of an encoded value. Arithmetic functions work on numbers, but annotation and label values are strings and need `to_number` first.

Collections and time complete the set. `items` turns a map into a list of key and value objects, `object_from_lists` builds a map back, and `label_match` tests whether one map is contained in another. `time_since` returns an elapsed duration as a string, which is compared with a duration operator rather than a numeric one. `semver_compare` compares versions correctly where a string comparison would not.

Key facts:

- The pattern is the first argument of `regex_match`.
- Annotation values are strings until converted.
- A duration result needs a duration operator.

<!-- astrona:playground:destroy -->
