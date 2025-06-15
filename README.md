# OCI Database Backup

Runs a simple `pg_dump` command and uploads to OCI object storage or S3 Object Storage

## PG Version

Assumes postgres version 16

## Volumes

All backup file data written to `/opt/backup/files` if you want to keep it on a data volume for consistency.

Mount a `cron-env` file to the `/opt/backup/env` directory for all environment vars.

## Environment Variables

For environment variables to be used in the cron job, place environment exports in a `/opt/backup/env/cron-env` file.

Requires:

- `BUCKET_NAME` - bucket in object storage
- `DATABASE_USER` - database user to connect with
- `DATABASE_HOST` - database host to connect to
- `DATABASE_NAME` - name of database
- `PGPASSWORD` - database password


## Object Storage Types

By default the system will default to S3 Object Storage, to override to OCI object storage use:

```
export STORAGE_BACKEND="oci"
```

## OCI Setup

If you want to set oci config files or auth options, place them in the `/opt/backup/env/cron-env` file.

## S3 Setup

Place the relevant environment exports in the `/opt/backup/env/cron-env` file, including:

- `AWS_ENDPOINT_URL_S3`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

## Optional Args

Pass in `PGDUMP_ARGS` to allow additional args on the pgdump command.