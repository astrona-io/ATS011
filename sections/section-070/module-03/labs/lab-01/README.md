# JMESPath Functions Lab

> [!WARNING]
> **UNTESTED**: this lab has not been run against a live cluster yet.

`kind` cluster for the KCA course with Kyverno v1.19.1 installed. Write one ClusterPolicy whose five rules each use a Kyverno JMESPath function to accept or reject a Pod.

## Run

```bash
astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-070/module-03/labs/lab-01
astrona submit -c sections/section-070/module-03/labs/lab-01
astrona destroy ats-011-lab-073
```
