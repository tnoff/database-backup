#!/bin/bash

if [ -z "$1" ]; then
  echo "Must pass backup file arg"
  exit 1
fi

BACKUP_FILE="$1"

# The key is the file name alone, not the local path: a key that starts with a slash
# ("/opt/backup/files/...") is accepted by Oracle's S3 API but rejected by S3-compatible
# gateways in front of it ("Object name contains unsupported characters") and breaks
# `aws s3 cp`.
aws s3api put-object --bucket "$BUCKET_NAME" --key "$(basename "$BACKUP_FILE")" --body "$BACKUP_FILE"