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

CI is GitHub Actions. `.github/workflows/` calls reusable workflows from
`tnoff/github-workflows`, SHA-pinned in `uses:` and kept current by Renovate:

| Caller | Reusable workflow | Purpose |
|---|---|---|
| `ci.yml` | `trufflehog.yml` | Secret scan on PRs |
| `ci.yml` | `docker-build-check.yml` | PR-time Dockerfile build check plus the image secret scan — one job, where GitLab needed two and a bucket to ship the tarball between them |
| `ci.yml` | `bump-version.yml` | Bump `VERSION` and write a changelog fragment on `renovate/dev-*` PRs |
| `ci.yml` | `renovate-auto-approve.yml` | Supply the code-owner approval Renovate cannot give itself |
| `release.yml` | `assemble-changelog.yml` | Fold `changelog.d/*.md` into `CHANGELOG.md` on `main` |
| `release.yml` | `tag.yml` | Tag from `VERSION` |
| `release.yml` | `docker-push.yml` | Build + push to OCIR |
| `release.yml` | `trigger-bump.yml` | Open an MR in `docker-apps` to bump the SHA pin |
| `scheduled.yml` | `renovate.yml`, `branch-cleanup.yml` | Weekly dependency updates and stale-branch pruning |

`.gitlab-ci.yml` is frozen in place for history and no longer runs.

`VERSION` at the repo root drives release tagging. Bump it, push to
`main`, CI handles the tag + push.

## Where it runs

The consumer manifest lives in
[`tnoff-projects/docker-apps/postgres/`](https://gitlab.com/tnoff-projects/docker-apps/-/tree/main/postgres)
as a Kubernetes CronJob. The schedule, secret mounts, and volume
mounts are defined there. Bumping the image is automatic via
`trigger-bump.yml`.
