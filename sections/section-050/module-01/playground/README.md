# Generation Rules — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-011-playground-050
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading



A `kind` cluster with Kyverno v1.19.1 installed and no policies on it, so you
can explore generation rules hands-on. Nothing to submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-011-playground-050
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-011-playground-050`), not
the config path. `astrona submit` and `astrona test` do not apply — there is no
grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition (runtime + bootstrap only) |
| `bootstrap/prepare.sh` | OS prep run once at startup |
| `docs/overview.md` | What the environment contains and ideas to try |
