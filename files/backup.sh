#!/bin/bash

set -ux;

echo "Starting backup script"
date -u

if [ -f /opt/backup/env/cron-env ]; then
  source /opt/backup/env/cron-env
fi

# If deployed within k9s container
LOCAL_DEPLOY="${LOCAL_DEPLOY:-false}"
# Bucket name
BUCKET_NAME="${BUCKET_NAME:-discord-test}"
# Other config args
CONFIG_FILE="${CONFIG_FILE:-/opt/oci/config/config}"
OCI_PREFIX="/opt/venv/bin/oci"

if [ $LOCAL_DEPLOY == "false" ]; then
  export OCI_CLI_AUTH=instance_principal
else
  OCI_PREFIX="$OCI_PREFIX --config-file $CONFIG_FILE"
fi

BACKUP_DIR="/opt/backup/files"
mkdir -p "$BACKUP_DIR"

datetime=$(date -u '+%Y-%m-%d')
backup_file="$BACKUP_DIR/$datetime.sql"

date -u >> /var/log/backup.log.err
pg_dump -h "${DATABASE_HOST}" -u "${DATABASE_USER}" "${DATABASE_NAME}" > "$backup_file"
gzip "$backup_file" --force
eval "$OCI_PREFIX" os object put -bn "$BUCKET_NAME" --file "$backup_file.gz" --name "$backup_file.gz" --force
find "$BACKUP_DIR" -type f -mtime +30 -delete