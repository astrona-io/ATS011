# Mutation Anchors Lab

> [!WARNING]
> **UNTESTED**: this lab has not been run against a live cluster yet.

`kind` cluster for the KCA course with Kyverno v1.19.1 installed. Default a label and a Pod setting with `+()` and harden only sidecar containers with a conditional anchor.

## Run

```bash
astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-040/module-03/labs/lab-01
astrona submit -c sections/section-040/module-03/labs/lab-01
astrona destroy ats-011-lab-043
```
