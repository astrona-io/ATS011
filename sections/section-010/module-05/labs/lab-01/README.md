# Assertion Trees Lab

> [!WARNING]
> **UNTESTED**: this lab has not been run against a live cluster yet.

`kind` cluster for the KCA course with Kyverno v1.19.1 installed. Write one `validate.assert` rule that rejects Pods with the default service account, a `:latest` image or a missing memory limit.

## Run

```bash
astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-010/module-05/labs/lab-01
astrona submit -c sections/section-010/module-05/labs/lab-01
astrona destroy ats-011-lab-015
```
