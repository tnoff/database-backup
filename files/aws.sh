#!/bin/bash

if [ -z "$1" ]; then
  echo "Must pass backup file arg"
  exit 1
fi

BACKUP_FILE="$1"

aws s3api put-object --bucket "$BUCKET_NAME" --key  "$BACKUP_FILE" --body "$BACKUP_FILE"  --no-verify-ssl