# Variables & API Calls Capstone Lab

`kind` cluster for the KCA course — Kyverno pre-installed, namespace `cap-a` pre-seeded with two Pods. Combine `context.apiCall` and `context.variable` in one policy: a live per-namespace Pod quota whose rejection message names the actual offending Pod.

## Run

```bash
astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-070/capstone/labs/lab-01
```
