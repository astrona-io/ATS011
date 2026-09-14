# Background Scanning — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-011-playground-030
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading



A `kind` cluster with Kyverno v1.19.1 installed and no policies on it, so you
can explore background scanning hands-on. Nothing to submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-011-playground-030
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-011-playground-030`), not
the config path. `astrona submit` and `astrona test` do not apply — there is no
grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition (runtime + bootstrap only) |
| `bootstrap/prepare.sh` | OS prep run once at startup |
| `docs/overview.md` | What the environment contains and ideas to try |
