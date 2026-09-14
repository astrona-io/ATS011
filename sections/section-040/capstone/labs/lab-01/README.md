# Mutation Rules Capstone Lab

`kind` cluster for the KCA course — Kyverno pre-installed, background-controller RBAC pre-granted. Write a `ClusterPolicy` that mutates new Pods at admission time *and* reaches back to retroactively patch Pods that already existed before the policy did.

## Run

```bash
astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-040/capstone/labs/lab-01
```
