# Database Backup

Runs a one-shot `pg_dump | gzip` and uploads the result to S3-compatible
object storage (OCI Object Storage in this fleet). Not a service: the container
runs once and exits.

## PG Version

The image ships `postgresql-client-17` by default. Override at build
time with `--build-arg POSTGRES_VERSION=<n>` if you need a different
major (e.g. when targeting an older database server).

## Volumes

Dumps are written to `/opt/backup/files` and deleted at the end of every run
(whether or not the upload succeeded), so S3 is the only record. The upload key
is the local path, `/opt/backup/files/<UTC timestamp>.sql.gz`.

Optionally mount a `cron-env` file at `/opt/backup/env/cron-env`; it is sourced
if present. Plain container environment variables work equally well.

## Environment Variables

Set these in the container environment, or as `export` lines in
`/opt/backup/env/cron-env`.

Requires:

- `BUCKET_NAME` - bucket in object storage
- `DATABASE_USER` - database user to connect with
- `DATABASE_HOST` - database host to connect to
- `DATABASE_NAME` - name of database
- `PGPASSWORD` - database password


## S3 Setup

Standard AWS CLI variables:

- `AWS_ENDPOINT_URL_S3`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

Against OCI's S3-compatible endpoint the fleet also sets
`AWS_REQUEST_CHECKSUM_CALCULATION=WHEN_REQUIRED` and
`AWS_RESPONSE_CHECKSUM_VALIDATION=WHEN_REQUIRED`, and `PGSSLMODE=require` for
the database connection (see the CronJobs below).

## Optional Args

`PGDUMP_ARGS` adds args to the `pg_dump` command; `GZIP_ARGS` adds args to
`gzip`. Both are split on whitespace.

## Consumers

The image is `iad.ocir.io/tnoff/database_backup`. In `tnoff/docker-apps` two
CronJobs run it, each its own catalog Component: `discord-database-backup`
(`apps/discord/backup-cronjob.yaml`, 11:00 UTC) and `backstage-database-backup`
(`apps/backstage/backup-cronjob.yaml`, 12:00 UTC). Each is configured entirely
through env and its own bucket credentials Secret; image pins are bumped
automatically via the `image-bump` dispatch on release. See
`techdocs/docker-apps` there (database backups) for the cross-repo picture.

## For developers

- [DEVELOPMENT.md](https://github.com/tnoff/database-backup/blob/main/docs/DEVELOPMENT.md) — build, local run, CI.
- [AGENTS.md](https://github.com/tnoff/database-backup/blob/main/docs/AGENTS.md) — non-obvious internals for AI coding agents.