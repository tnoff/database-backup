# OCI Database Backup

Runs a simple `pg_dump` command and uploads to OCI object storage.

## Environment Variables

For environment variables to be used in the cron job, place environment exports in a `/opt/backup/env/cron-env` file.

Requires:

- `BUCKET_NAME` - bucket in oci object storage
- `DATABASE_USER` - database user to connect with
- `DATABASE_HOST` - database host to connect to
- `PGPASSWORD` - database password


If you want to set oci config files or auth options, place a config file in `/opt/oci/config` and set the `OCI_CONFIG_FILE` env variable.