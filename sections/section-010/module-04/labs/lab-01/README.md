# podSecurity Lab

> [!WARNING]
> **UNTESTED**: this lab has not been run against a live cluster yet.

`kind` cluster for the KCA course with Kyverno v1.19.1 installed. Enforce the baseline Pod Security profile and relax one control for one image.

## Run

```bash
astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-010/module-04/labs/lab-01
astrona submit -c sections/section-010/module-04/labs/lab-01
astrona destroy ats-011-lab-014
```
