#!/bin/bash

set -ux;

echo "Starting backup script"
date -u

if [ -f /opt/backup/env/cron-env ]; then
  # Runtime-only, mounted at deploy time -- never present at lint time by
  # design.
  # shellcheck disable=SC1091
  source /opt/backup/env/cron-env
fi

# Intentional word-splitting: these are operator-set config (cron-env), not
# untrusted input, and the whole point is turning a space-separated string
# into argv entries.
# shellcheck disable=SC2206
PGDUMP_ARGS=(${PGDUMP_ARGS:-})
# shellcheck disable=SC2206
GZIP_ARGS=(${GZIP_ARGS:-})

BACKUP_DIR="/opt/backup/files"
mkdir -p "$BACKUP_DIR"

datetime=$(date -u '+%Y-%m-%d-%H-%M-%S')
backup_file="$BACKUP_DIR/$datetime.sql"

date -u >> /var/log/backup.log.err
pg_dump "${PGDUMP_ARGS[@]}" -h "${DATABASE_HOST}" -U "${DATABASE_USER}" "${DATABASE_NAME}" > "$backup_file"
gzip "${GZIP_ARGS[@]}" "$backup_file" --force

/opt/backup/aws.sh "$backup_file.gz"

find "$BACKUP_DIR" -type f -delete