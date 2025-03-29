#!/bin/bash

if [ -z "$1" ]; then
  echo "Must pass backup file arg"
  exit 1
fi

BACKUP_FILE="$1"

oci os object put -bn "$BUCKET_NAME" --file "$backup_file.gz" --name "$BACKUP_FILE" --force
