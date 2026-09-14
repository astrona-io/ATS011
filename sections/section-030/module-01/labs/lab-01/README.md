# Background Scanning Lab

`kind` cluster for the KCA course -- Kyverno pre-installed, plus three Pods created in a `legacy-apps` namespace *before* any policy exists. Write an Audit-mode `ClusterPolicy` with `background: true` and prove it reports on those pre-existing Pods without blocking them.

## Run

```bash
astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-030/module-01/labs/lab-01
```
