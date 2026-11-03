# Image Extraction Lab

> [!WARNING]
> **UNTESTED**: this lab has not been run against a live cluster yet.

`kind` cluster for the KCA course with Kyverno v1.19.1 installed. Use the `images` variable to restrict registries and block the `latest` tag for Pods and Deployments.

## Run

```bash
astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-060/module-03/labs/lab-01
astrona submit -c sections/section-060/module-03/labs/lab-01
astrona destroy ats-011-lab-063
```
