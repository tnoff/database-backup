# Development

Build, local run, and CI for this image. User-facing env-var setup and
volume mounts live in [README.md](README.md); for non-obvious script
internals see [AGENTS.md](AGENTS.md).

## Prerequisites

- Docker
- A reachable PostgreSQL instance (for local end-to-end testing)
- S3-compatible storage credentials (for upload testing)

## Build

```bash
docker build -t database-backup .
```

To target a different PostgreSQL client major:

```bash
docker build --build-arg POSTGRES_VERSION=16 -t database-backup .
```

## Run locally

The image is one-shot — `CMD` runs `backup.sh` and exits. To test end
to end against a real database + bucket:

```bash
cat > cron-env <<EOF
export BUCKET_NAME=my-backup-bucket
export DATABASE_HOST=db.example.com
export DATABASE_USER=postgres
export DATABASE_NAME=mydb
export PGPASSWORD=secret
export AWS_ENDPOINT_URL_S3=https://<namespace>.compat.objectstorage.<region>.oraclecloud.com
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
EOF

docker run --rm \
  -v "$PWD/cron-env:/opt/backup/env/cron-env:ro" \
  -v "$PWD/backups:/opt/backup/files" \
  database-backup
```

Add `-it --entrypoint bash` to get a shell instead of running the
script directly.

## Iterating on `backup.sh`

The script is small enough to iterate by editing on disk and
rebuilding, but you can also mount it over the baked-in copy:

```bash
docker run --rm \
  -v "$PWD/files/backup.sh:/opt/backup/backup.sh:ro" \
  -v "$PWD/cron-env:/opt/backup/env/cron-env:ro" \
  database-backup
```

## Linting

There's no test suite. `shellcheck` on the two shell scripts is the
closest thing to lint:

```bash
shellcheck files/backup.sh files/aws.sh
```

## CI / release

CI is GitLab CI. `.gitlab-ci.yml` pulls templates from
`tnoff-projects/github-workflows`:

| Template | Purpose |
|---|---|
| `buildkit-build-check.yml` | MR-time Dockerfile build check |
| `buildkit-docker-push.yml` | Build + push to OCIR on default branch |
| `trigger-bump.yml` | Open an MR in `docker-apps` to bump the SHA pin |
| `trufflehog.yml`, `trufflehog-image.yml` | Secret scans (repo + image) |
| `tag.yml`, `bump-version.yml` | Tag from `VERSION`, bump on default branch |
| `renovate.yml` | Scheduled dependency updates |
| `discord-notify.yml` | Pipeline-failure notifications |

`VERSION` at the repo root drives release tagging. Bump it, push to
`main`, CI handles the tag + push.

## Where it runs

The consumer manifest lives in
[`tnoff-projects/docker-apps/postgres/`](https://gitlab.com/tnoff-projects/docker-apps/-/tree/main/postgres)
as a Kubernetes CronJob. The schedule, secret mounts, and volume
mounts are defined there. Bumping the image is automatic via
`trigger-bump.yml`.
