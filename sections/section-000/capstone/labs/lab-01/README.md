# Policy Objects Capstone Lab

> [!WARNING]
> **UNTESTED**: this lab has not been run against a live cluster yet.

`kind` cluster for the KCA course with Kyverno v1.19.1 installed. Combine a mutate rule, a validate rule, an exclude block and a precondition in one ClusterPolicy.

## Run

```bash
astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-000/capstone/labs/lab-01
astrona submit -c sections/section-000/capstone/labs/lab-01
astrona destroy ats-011-lab-000
```
