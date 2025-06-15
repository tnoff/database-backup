#!/bin/bash

set -ux;

echo "Starting backup script"
date -u

if [ -f /opt/backup/env/cron-env ]; then
  source /opt/backup/env/cron-env
fi

STORAGE_BACKEND="${STORAGE_BACKEND:-s3}"
PGDUMP_ARGS=(${PGDUMP_ARGS:-})
GZIP_ARGS=(${GZIP_ARGS:-})

BACKUP_DIR="/opt/backup/files"
mkdir -p "$BACKUP_DIR"

datetime=$(date -u '+%Y-%m-%d')
backup_file="$BACKUP_DIR/$datetime.sql"

date -u >> /var/log/backup.log.err
pg_dump "${PGDUMP_ARGS[@]}" -h "${DATABASE_HOST}" -U "${DATABASE_USER}" "${DATABASE_NAME}" > "$backup_file"
gzip "${GZIP_ARGS[@]}" "$backup_file" --force

if [ "${STORAGE_BACKEND}" == "oci" ]; then
  /opt/backup/oci.sh "$backup_file.gz"
fi
if [ "${STORAGE_BACKEND}" == "s3" ]; then
  /opt/backup/aws.sh "$backup_file.gz"
fi

find "$BACKUP_DIR" -type f -delete