# Background Scans Capstone Lab

`kind` cluster for the KCA course -- Kyverno pre-installed, plus three Pods in a `legacy-services` namespace created before any policy exists (one of them still running an unpinned `:latest` image). Write a two-rule `ClusterPolicy` and demonstrate that a rule gated on request-only context behaves differently from a plain rule during a background scan.

## Run

```bash
astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-030/capstone/labs/lab-01
```
