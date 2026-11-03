# Question

Kyverno is installed and the namespace `fn-lab` exists. Pods in that namespace must carry annotations that describe who owns them and how they were approved.

Write one `ClusterPolicy` named `pod-functions` with `validationFailureAction: Enforce` and `background: false`. It has five validate rules, each matching Pods in `fn-lab` and each using `validate.deny`:

1. Rule `name-format`: reject a Pod whose name does not match the regular expression `^[a-z]+-[0-9][0-9]$` (for example `web-01` is allowed and `Web-1` is not). Use `regex_match`.
2. Rule `owner-team`: the annotation `owner` has the form `team/app`. Reject the Pod when the team part, upper-cased, is not `PLATFORM`. A Pod with no `owner` annotation is rejected. Use `split` and `to_upper`.
3. Rule `config-decoded`: the annotation `config` holds a base64 value. Reject the Pod when the decoded text is not `ready`. Use `base64_decode`.
4. Rule `budget`: the annotations `requested` and `used` hold whole numbers as strings. Reject the Pod when `used` is greater than `requested`. Use `to_number` and `subtract`.
5. Rule `fresh-approval`: the annotation `approved` holds an RFC 3339 timestamp. Reject the Pod when it is more than 24 hours old. Use `time_since` and a duration operator.

Annotations that are present and valid must not make a rule fire. A Pod that satisfies all five requirements must be admitted.
