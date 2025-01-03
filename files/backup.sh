#!/bin/bash

set -ux;

echo "Starting backup script"
date -u

if [ -f /opt/backup/env/cron-env ]; then
  source /opt/backup/env/cron-env
fi

OCI_PREFIX="/opt/venv/bin/oci"
if [ ! -z OCI_CONFIG_FILE ]; then
  OCI_PREFIX="$OCI_PREFIX --config-file $OCI_CONFIG_FILE"
fi

BACKUP_DIR="/opt/backup/files"
mkdir -p "$BACKUP_DIR"

datetime=$(date -u '+%Y-%m-%d')
backup_file="$BACKUP_DIR/$datetime.sql"

date -u >> /var/log/backup.log.err
pg_dump -h "${DATABASE_HOST}" -U "${DATABASE_USER}" "${DATABASE_NAME}" > "$backup_file"
gzip "$backup_file" --force
eval "$OCI_PREFIX" os object put -bn "$BUCKET_NAME" --file "$backup_file.gz" --name "$backup_file.gz" --force
find "$BACKUP_DIR" -type f -delete