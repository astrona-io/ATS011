# Live Pod-Quota Lab (context.apiCall)

`kind` cluster for the KCA course — Kyverno pre-installed, namespace `team-a` pre-seeded with two Pods. Write a `ClusterPolicy` that uses `context.apiCall` to count Pods per namespace, live, and enforces a 3-Pod limit.

## Run

```bash
astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-070/module-01/labs/lab-01
```
