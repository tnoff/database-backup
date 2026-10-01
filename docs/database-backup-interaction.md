# Database backups (postgres → OCI bucket)

How nightly postgres backups get from in-cluster Postgres databases into
OCI Object Storage buckets. **Two backups today — discord and backstage.**
(Both CronJobs live in docker-apps and invoke this repo's image; the
discord database is a plain Postgres Deployment since the postgres
operator / Patroni was replaced on 2026-09-28.) The grafana
backup was retired on 2026-06-27 when Grafana moved off `grafana-pg`
Postgres to **SQLite on a PVC** (`docker-apps` `93c0984`), so there is no
Grafana database to dump anymore; its bucket + IAM creds were torn down
in terraform `0fd4868`. The pattern below is still the 4-repo,
parameterized shape — grafana is retained in the prose only as the second
worked example of "how you'd add another". Reuses the terraform →
docker-apps secret-injection contract from workload deployment (docker-apps TechDocs).

## TL;DR

- **terraform `oci/`** creates a per-DB bucket and a single-purpose IAM
  user scoped (via `where_clause`) to that bucket only, exposed as
  remote-state outputs.
- **terraform `apps/`** reads those outputs and writes a Kubernetes
  Secret into the Flux-managed consumer namespace — same pattern as the
  image-pull secret contract (workload deployment #2, docker-apps TechDocs).
- **docker-apps** owns the CronJob, image
  `iad.ocir.io/tnoff/database_backup:<sha>`, pin-bumped by the standard
  producer flow (image promotion, docker-apps TechDocs) — the `.trigger-bump` rewrites
  the CronJob manifest on one branch.
- **database-backup** is a thin bash tool: `pg_dump` → `gzip` →
  `aws s3api put-object`. No retention on the tool side — lifecycle is
  enforced at the bucket (`delete_after = 14` days).

## Active backups

Discord and backstage are the live backups. (Grafana column removed — see
the header note; `grafana-pg`, its bucket, IAM user, Secret and CronJob are
all gone.)

| | discord | backstage |
|---|---|---|
| Postgres | `discord-pg` (`discord-postgres` ns, plain Postgres Deployment) | `backstage-pg` (`backstage-postgres` ns) |
| DB user/name | `discord.discord` / `discord` | `backstage.backstage` / `backstage` |
| Bucket (in `apps_compartment`, `us-sanjose-1`, 14-day expiry) | `discord_database_backups` | `backstage_database_backups` |
| IAM user | `db-backup-bot-push-bot` | not verified |
| K8s Secret (terraform/apps) | `discord-database-backup-os-credentials` in `discord` ns | `backstage-database-backup-os-credentials` in `backstage` ns |
| CronJob path | `apps/discord/backup-cronjob.yaml` | `apps/backstage/backup-cronjob.yaml` |
| Schedule (UTC) | `0 11 * * *` | `0 12 * * *` |
| `PGPASSWORD` source | Postgres credentials Secret (no longer operator-issued) | same |
| `nodeSelector` | `node_role: default` | `node_role: default` |

## The flow

Same shape for every backup; the per-instance names come from the table
above.

```
┌──────────────────────────┐                ┌──────────────────────────┐
│ terraform/oci/oci.tf     │                │ terraform/apps/main.tf   │
│                          │                │                          │
│ module "<db>_database"   │                │ kubernetes_secret_v1     │
│   bucket, 14d delete,    │ remote_state   │   "<db>_database_        │
│   KMS-encrypted          │ ─────────────▶ │    backup_os_push"       │
│                          │ outputs        │                          │
│ module "<db>_database_   │                │ ns: <consumer>           │
│   backup_creds"          │                │ keys: AWS_ACCESS_KEY_ID, │
│   IAM user + S3 keys     │                │   AWS_SECRET_ACCESS_KEY, │
│   policy scoped to bucket│                │   BUCKET_NAME,           │
└──────────────────────────┘                │   AWS_OS_ENDPOINT, ...   │
                                            └────────────┬─────────────┘
                                                         │ kubectl apply
                                                         │ (hosted runner,
                                                         │  bastion tunnel)
                                                         ▼
┌──────────────────────────┐                ┌──────────────────────────┐
│ database-backup repo     │  image push    │ OKE: <consumer> ns       │
│ files/backup.sh          │ ─────────────▶ │                          │
│   pg_dump | gzip         │ (image-promo)  │ CronJob                  │
│ files/aws.sh             │                │   <db>-database-backup   │
│   aws s3api put-object   │                │   image: database_backup │
└──────────────────────────┘                │   envFrom + env: secret  │
                                            │                          │
                                            │ Reads <db>-pg.<ns>       │
                                            │   .svc → pg_dump → S3   │
                                            └────────────┬─────────────┘
                                                         │
                                                         ▼
                                            OCI Object Storage bucket
                                            (us-sanjose-1, S3-compat)
                                            <namespace>.compat.
                                              objectstorage.us-sanjose-1
                                              .oraclecloud.com
                                            → <db>_database_backups/
                                              YYYY-MM-DD-HH-MM-SS.sql.gz
```

## terraform/oci — the buckets and their credentials

The discord backup (and, in the same shape, the backstage one —
`backstage_database_backups`) has a `terraform-modules//oci/object-storage-bucket`
module in `oci.tf` and a sibling `terraform-modules//oci/iam-user` module
that provisions the IAM user with a `where_clause`-scoped policy. (The
grafana pair — `module.grafana_database` / `module.grafana_database_backup_creds`
— was deleted in terraform `0fd4868`.)

| | discord |
|---|---|
| Bucket module | `module.discord_database` (`oci.tf:279`) |
| IAM module | `module.discord_database_backup_creds` (`oci.tf:549`) |
| Customer secret key name | `db-backup-bot-push-creds` |

The bucket is KMS-encrypted via `module.vault.kms_key.id`,
`delete_after = 14`, `archive_after = 0` (hot tier only),
`abort_incomplete_uploads_after = 3`. The IAM user has a single
`manage object-family` policy statement with
`where_clause = "where any {target.bucket.name = '<this-bucket>'}"` —
no cross-bucket access.

Outputs exposed for downstream consumption (`terraform/oci/outputs.tf`):

- `discord_database_bucket_name` — the bucket name
- `database_backup_push_access_key` / `_secret_key` — the S3-compat
  credential pair (marked `sensitive`). Note the discord pair uses the
  shorter legacy names (no `discord_` prefix) for historical reasons.
- `object_storage_s3_endpoint_url` — region-templated:
  `<namespace>.compat.objectstorage.us-sanjose-1.oraclecloud.com`

→ **Bucket lives in `us-sanjose-1` (the app region), not `us-ashburn-1`
(the home region where state buckets live).** The S3 endpoint URL is
built from `local.app_region` in `oci.tf:41-42`.

## terraform/apps — secret injection into the consumer namespace

One `kubernetes_secret_v1` resource in `apps/main.tf` (the grafana twin
`grafana_database_backup_os_push` was removed in `0fd4868`):

| | discord |
|---|---|
| Resource | `discord_database_backup_os_push` (`apps/main.tf:56`) |
| Secret name | `discord-database-backup-os-credentials` |
| Namespace | `discord` |

It writes 6 keys, sourced from the `discord_database_*` /
`object_storage_*` remote-state outputs:

```
AWS_ACCESS_KEY_ID     = oci.database_backup_push_access_key
AWS_SECRET_ACCESS_KEY = oci.database_backup_push_secret_key
BUCKET_NAME           = oci.discord_database_bucket_name
AWS_OS_ENDPOINT       = oci.object_storage_s3_endpoint_url
AWS_DEFAULT_REGION    = oci.object_storage_home_region
AWS_REGION            = oci.object_storage_app_region
```

The `discord` namespace (and `backstage` for its twin Secret) is created by Flux from docker-apps; this Secret
is dropped in after the namespace exists — same ordering rule as the
image-pull secret contract. The `apps/` stack runs on a **GitHub-hosted runner**, reaching
the private OKE API through an OCI Bastion tunnel and authenticating as the CI OCI user
(cluster-admin). Until 2026-09-04 it ran on the `oke-elevated` runner as the scoped
`terraform-apps` ServiceAccount, whose `terraform-apps-secrets` ClusterRole had to cover
`discord`; that identity is retired. (`local.kubernetes_enabled_namespaces` derives from
the bootstrap stack's `app_namespaces` remote-state output.)

→ **A backup in a *fresh* namespace needs that namespace in the
enabled-namespaces set** so the OCIR image-pull secret `oci-docker-cfg`
reaches it too — otherwise the CronJob `ImagePullBackOff`s. (This was the
lesson from adding the grafana backup in `monitoring`, since retired.)

## docker-apps — the CronJob

The `discord-database-backup` CronJob (`apps/discord/backup-cronjob.yaml`;
`backstage-database-backup` in `apps/backstage/backup-cronjob.yaml` is the
same with names swapped, at 12:00 UTC):
`concurrencyPolicy: Forbid`, 3 successful + 3 failed history limit,
`restartPolicy: OnFailure`, `imagePullSecrets: [oci-docker-cfg]`,
50m/200m CPU + 128Mi/256Mi memory, container name `discord-backup`.

The interesting bits beyond namespace/host/user/password:

| | discord |
|---|---|
| `nodeSelector` | `node_role: default` (workload pool) |
| Pod labels | `app: discord` |
| DB host | `discord-pg.discord-postgres.svc.cluster.local` |
| DB user (cross-ns role) | `discord.discord` |

→ **The backup pod carries the `postgres-access: "true"` label the
NetworkPolicy requires — resolved, and now load-bearing.**
`discord-postgres` carries an `allow-postgres-clients` NetworkPolicy admitting ingress to
`discord-pg:5432` only from pods labelled `postgres-access: "true"` — the
netpol's own comment says it's "Used by discord-bot and the discord backup
CronJob (which gains the label in phase 3)". discord-bot
(`discord-app.yaml`), the broker (`broker-app.yaml`) and the backup
CronJob's pod template all set it, and discord is fully cut over to
`discord-pg` (host + `PGSSLMODE=require` + the cross-ns `discord.discord`
role live in the CronJob).

This doc previously flagged the label as **missing**, which was true when
written. Two things changed and they matter in opposite directions:

- The label was added as gap **B2** of
  [`projects/network-policy-enforcement.md`](https://github.com/tnoff/docs/blob/main/projects/network-policy-enforcement.md) (verified present in
  `apps/discord/backup-cronjob.yaml`).
- That project also **installed Calico in policy-only mode**, so the
  NetworkPolicy is no longer inert. Before it landed, the missing label
  was harmless — nothing enforced the policy. Now the label is what keeps
  `pg_dump` reachable, so removing it would silently break nightly backups
  rather than doing nothing. Treat it as required on any new pod that
  talks to `discord-pg`.

Environment sourcing:

- `envFrom` pulls *all keys* from the OS-credentials Secret, so
  `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`,
  `AWS_REGION` all arrive automatically.
- Explicit `env:` overrides remap two keys:
  - `BUCKET_NAME` ← `secret.BUCKET_NAME` (redundant with envFrom but
    explicit)
  - `AWS_ENDPOINT_URL_S3` ← `secret.AWS_OS_ENDPOINT` (the real rename —
    `aws s3api` reads `AWS_ENDPOINT_URL_S3`, terraform stores the value
    as `AWS_OS_ENDPOINT`)
- `PGPASSWORD` ← the Postgres credentials Secret for the `discord.discord`
  role (key `password`). This used to be the postgres-operator-issued
  Secret `discord.discord.discord-pg.credentials.postgresql.acid.zalan.do`;
  the operator was replaced on 2026-09-28. A `PGSSLMODE=require` env is
  set alongside.
- `AWS_REQUEST_CHECKSUM_CALCULATION=WHEN_REQUIRED` and matching
  response variant — disables newer awscli default of always sending
  checksums, which OCI S3-compat doesn't support.

## database-backup — the tool itself

The image (`iad.ocir.io/tnoff/database_backup`) runs the CronJob.
`database-backup/files/backup.sh` is the entrypoint:

1. Sources optional `/opt/backup/env/cron-env` (not used by the
   CronJob — all env arrives from K8s).
2. `mkdir -p /opt/backup/files`.
3. Names the dump `YYYY-MM-DD-HH-MM-SS.sql` from `date`.
4. `pg_dump $PGDUMP_ARGS -h $DATABASE_HOST -U $DATABASE_USER
   $DATABASE_NAME > <file>`.
5. `gzip $GZIP_ARGS <file> --force`.
6. Calls `/opt/backup/aws.sh` which runs
   `aws s3api put-object --bucket $BUCKET_NAME --key <file.gz>
   --body <file.gz>`.
7. Deletes everything in `/opt/backup/files`.

→ **The tool has no retention logic of its own.** It uploads and forgets.
Retention is entirely the bucket's `delete_after = 14` lifecycle. If you
need a longer history, change it in `terraform/oci/oci.tf`, not in the
tool.

→ **`backup-tool` (in the manifest) is a different project** — a Python
AES-encrypted file-backup utility with its own SQLite tracking DB. Not
involved in this flow.

## Gotchas

- **The backup remains a meaningful durability layer.** `discord-pg` is
  a plain Postgres Deployment on a real `oci-bv` PVC (no longer `emptyDir`
  — see workload deployment "Supporting infra" in the docker-apps TechDocs), so a pod reschedule
  no longer loses data. The bucket is still the off-cluster copy; a volume
  loss + missed backup window can still mean data loss.
- **`delete_after = 14` is the retention.** Anything older than 14 days
  is gone. There is no archive copy.
- **One IAM user per bucket, write+read+delete scope.** The backup user
  has `manage object-family` scoped to its bucket — it can *delete*
  objects too, not just put. A compromise of the K8s secret could wipe
  the DB's history. (Mitigated by the bucket being versioned via the
  module default, but verify before relying on it.)
- **`AWS_OS_ENDPOINT` vs `AWS_ENDPOINT_URL_S3`.** Terraform stores the
  value under the former key name; awscli expects the latter. The
  CronJob remaps via an explicit `env:` entry. If you copy this pattern
  to a second backup, don't drop the remap.
- **Checksum env vars are required.** Without
  `AWS_REQUEST_CHECKSUM_CALCULATION=WHEN_REQUIRED`, newer awscli
  versions send checksum headers OCI S3-compat rejects. If you bump the
  awscli base image and uploads start failing, check this first.
- **No alerting on missed backups.** The CronJob's failure state is
  visible only via `failedJobsHistoryLimit: 3` and whatever Loki picks
  up. No PrometheusRule fires on a missed run. (This is what would make a
  netpol-blocked dump dangerous — it fails silently, which is why the
  `postgres-access` label above is worth keeping in view now that Calico
  actually enforces the policy.)
- **The dump runs as the per-DB backup role.** If that role loses
  read access to a table, the dump silently omits it. Permissions live
  in the postgres cluster's bootstrap (the
  `postgres-init-scripts` ConfigMap), not in this repo.

## Adding another backup

If a new postgres lands and needs the same treatment, the four-step
recipe is (grafana was the last one added this way, since retired):

1. **terraform/oci**: add `module "<db>_database"` (bucket) and
   `module "<db>_database_backup_creds"` (IAM user). Mirror an existing
   pair. Add 3 outputs.
2. **terraform/apps**: add `kubernetes_secret_v1
   "<db>_database_backup_os_push"` in the consumer namespace, sourced
   from the new outputs. If the consumer namespace is brand new, also
   add it to `app_namespaces` in the terraform `bootstrap` stack. **No RoleBinding step**
   — that was required until 2026-09-04, when the `terraform-apps` identity was retired;
   CI is cluster-admin now and writes into any namespace.
3. **docker-apps**: drop a `backup-cronjob.yaml` next to the consumer
   workload's other manifests, register it in the kustomization, and
   remember the `postgres-access: "true"` pod label if the target
   cluster's NetworkPolicy requires it.
4. **docs**: extend the inventory tables above.

---

## Verified against

| Project | SHA | Date |
|---|---|---|
| `terraform` | `eaa9770` | 2026-07-14 |
| `docker-apps` (CronJob path, schedule, `postgres-access` labels) | `2c724d1` | 2026-09-03 |
| `docker-apps` (netpol label + Calico enforcement) | `8e30deb4` | 2026-08-22 |
| `database-backup` | `96deefd` | 2026-07-14 |

*Related: workload deployment (docker-apps TechDocs; the terraform→docker-apps secret-
injection contract this reuses, plus the postgres clusters being backed
up), image promotion (docker-apps TechDocs; how `database_backup` image bumps land in
the CronJob via the `.trigger-bump`),
infra bootstrap (terraform-admin TechDocs; the remote-state plumbing that lets `apps/` read
`oci/` outputs).*
