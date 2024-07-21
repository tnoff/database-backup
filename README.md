# Discord Backup

Container that runs a cron job that executes the `discord-bot <config> db_dump` command and saves to OCI object storage.

## Volume Mounts

Expects a working `discord.cnf` file mounted in the `/opt/discord/cnf` directory within the container.

## Environment Variables

Requires a bucket to upload the files to, set via `BUCKET_NAME`.

For local deploys, use `LOCAL_DEPLOY=true` and place the required oci-cli files as a mount within the `/opt/oci/config` dir on the container.

For environment variables to be used in the cron job, place environment exports in a `/opt/cron-env` file.