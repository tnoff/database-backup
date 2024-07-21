#!/bin/bash

set -ux;

echo "Starting backup script"
date -u

echo "Getting other variables"

# If deployed within k9s container
LOCAL_DEPLOY="${LOCAL_DEPLOY:-false}"

CONFIG_FILE="${CONFIG_FILE:-/opt/oci/config/config}"

OCI_PREFIX="/opt/discord-venv/bin/oci"
DISCORD_PREFIX="/opt/discord-venv/bin/discord-bot"
DISCORD_CONF="/opt/discord/cnf/discord.cnf"

if [ $LOCAL_DEPLOY == "false" ]; then
  export OCI_CLI_AUTH=instance_principal
else
  OCI_PREFIX="$OCI_PREFIX --config-file $CONFIG_FILE"
fi

echo "Using prefix ${OCI_PREFIX}"

echo "Creating backup dir"
BACKUP_DIR="/opt/backup/files"
mkdir -p "$BACKUP_DIR"

echo "Generating backup file"
datetime=$(date -u '+%Y-%m-%d')
backup_file="$BACKUP_DIR/$datetime.json"
eval "$DISCORD_PREFIX" "$DISCORD_CONF" db_dump 2>/dev/null > "$backup_file"
gzip "$backup_file" --force

echo "Uploading backup file"
eval "$OCI_PREFIX" os object put -bn "$BUCKET_NAME" --file "$backup_file.gz" --name "$backup_file.gz" --force

find "$BACKUP_DIR" -type f -mtime +30 -delete