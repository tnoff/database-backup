# OCI Database Backup

Runs a simple `pg_dump` command and uploads to OCI object storage.

## Environment Variables

For environment variables to be used in the cron job, place environment exports in a `/opt/backup/env/cron-env` file.

Requires:

- `BUCKET_NAME` - bucket in oci object storage
- `DATABASE_USER` - database user to connect with
- `DATABASE_HOST` - database host to connect to
- `PGPASSWORD` - database password

Optional
- `LOCAL_DEPLOY` - if true, uses oci auth key, if false uses instance principal. 

For local deploys, use `LOCAL_DEPLOY=true` and place the required oci-cli files as a mount within the `/opt/oci/config` dir on the container.