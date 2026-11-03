# Attestors and Digests Lab

> [!WARNING]
> **UNTESTED**: this lab has not been run against a live cluster yet.

`kind` cluster for the KCA course with Kyverno v1.19.1 installed. Build a verifyImages rule with an attestor set, two keys and digest settings.

## Run

```bash
astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-060/module-02/labs/lab-01
astrona submit -c sections/section-060/module-02/labs/lab-01
astrona destroy ats-011-lab-062
```
