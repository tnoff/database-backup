# AGENTS.md

Guidance for AI coding agents working in this repository. For end-user
docs (env vars, S3 setup, volumes) see [README.md](README.md); for
build, local run, and CI see [DEVELOPMENT.md](DEVELOPMENT.md).

## What this image does

One-shot `pg_dump | gzip | aws s3api put-object` runner. The container
is not meant to be long-running — the Kubernetes deployment in
[`docker-apps/postgres/`](https://gitlab.com/tnoff-projects/docker-apps/-/tree/main/postgres)
schedules it as a CronJob that runs to completion. No in-container
cron daemon despite the file name (`cron-env`).

Shape:

```
.
├── Dockerfile          # python:3.14-slim + postgres client + awscli
├── files/
│   ├── backup.sh       # entrypoint — invoked by `CMD` in the Dockerfile
│   └── aws.sh          # thin wrapper around `aws s3api put-object`
├── requirements.txt    # awscli pin (only Python dep)
└── VERSION             # source of truth for release tagging
```

## Non-obvious internals

### `cron-env` file is sourced at runtime, not built in

`backup.sh` checks for `/opt/backup/env/cron-env` and `source`s it if
present. That file is intentionally **not** baked into the image —
it's mounted from outside (a Kubernetes Secret, a docker volume, etc.)
so credentials never live in the image layer. If the file isn't
mounted, `pg_dump` still runs but will fail without `PGPASSWORD` /
`DATABASE_*` set in the container's env.

### `aws.sh` uses `--no-verify-ssl`

`aws s3api put-object --no-verify-ssl` is required when talking to OCI
Object Storage via the S3-compatible endpoint with an OCI-issued
certificate that the awscli's CA bundle doesn't trust. It's not a
general-purpose "skip SSL" — it's the specific workaround for that
endpoint. Don't propagate this flag to other AWS-CLI calls and don't
remove it without confirming the bucket endpoint's cert chain is
recognised.

### `PGDUMP_ARGS` and `GZIP_ARGS` are arrays, not strings

```bash
PGDUMP_ARGS=(${PGDUMP_ARGS:-})
GZIP_ARGS=(${GZIP_ARGS:-})
```

The env var is read as a single string and split on IFS, so values
with embedded spaces (e.g. `--exclude-table=public.foo bar`) will be
split unexpectedly. If a downstream config needs that, switch to
`mapfile` or pass JSON and parse with `jq`.

### Working directory is wiped after each run

`backup.sh` ends with `find "$BACKUP_DIR" -type f -delete`. The
gzipped dump is uploaded then removed. If the upload fails, the file
is deleted anyway — there is **no local retention**. Don't rely on
the volume mount as a backup-of-the-backup; treat S3 as the only
record.

### Postgres major is a build arg

`ARG POSTGRES_VERSION=17` in the Dockerfile sets the default. The
README previously claimed "postgres 16" — the actual default is now
17. To bump the bundled client, edit the ARG default; CI rebuilds and
the consumer in `docker-apps` picks up the new SHA pin automatically.

### `set -ux` (no `e`)

`backup.sh` runs under `set -ux` but **not** `-e`. That's deliberate:
if `pg_dump` fails, the script still attempts the (now empty) upload
so the failure surfaces in CloudWatch / OCI logging as an empty file
rather than a silent missing job. Don't add `-e` — it would short-
circuit error reporting.

### Backup file naming

```
$BACKUP_DIR/$(date -u '+%Y-%m-%d-%H-%M-%S').sql.gz
```

UTC timestamp to the second. Two runs in the same second would
collide; nothing in this image guards against it because the CronJob
schedule never schedules sub-second.

## Conventions

- New env vars need a row in [README.md](README.md#environment-variables).
- New optional CLI args follow the `<UPPER>_ARGS` pattern read as an
  array (see PGDUMP_ARGS).
- The image stays one-shot — no in-container scheduling, no daemons.
