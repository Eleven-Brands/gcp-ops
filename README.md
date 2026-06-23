# gcp-ops

Recurring operational scripts and runbooks for managing Google Cloud
Platform resources — IAM reviews, access governance, query
optimization, and related housekeeping tasks. Not tied to a single
project; scoped to GCP operations broadly.

## Structure

```
gcp-ops/
├── iam_review/
│   ├── README.md                  # process + script usage
│   └── export_iam.sh              # exports project + org IAM bindings
├── query_optimization/
│   ├── README.md                  # process + script usage
│   ├── best-practices.md          # query-writing checks + REST API timing technique
│   └── find_expensive_queries.sh  # exports slow/expensive queries from INFORMATION_SCHEMA.JOBS_BY_PROJECT
├── .github/                       # CI — synced from eleven-brands-engineering-standards
│   ├── CODEOWNERS
│   ├── ISSUE_TEMPLATE/
│   └── workflows/
├── scripts/
│   └── sync_engineering_standards.sh
├── CODE_OF_CONDUCT.md             # synced — don't hand-edit, see below
├── CONTRIBUTING.md                # synced — don't hand-edit, see below
├── LICENSE                        # synced — don't hand-edit, see below
├── setup_gcp.md                   # synced — don't hand-edit, see below
└── setup_local_development.md     # synced — don't hand-edit, see below
```

Each subfolder under the top level (`iam_review/`, `query_optimization/`)
is a self-contained recurring task. As new GCP ops needs come up (billing
checks, quota reviews, service account audits, etc.), add a new subfolder
following the same pattern rather than overloading an existing one.

## Engineering standards sync

This repo is a registered consumer of
[`eleven-brands-engineering-standards`](https://github.com/Eleven-Brands/eleven-brands-engineering-standards).
`CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `LICENSE`, `setup_gcp.md`,
`setup_local_development.md`, and the `.github/` conventions are pulled
in automatically by `.github/workflows/sync-engineering-standards.yml`
whenever that repo changes. Don't hand-edit those files here — propose
the change in the standards repo instead, and it propagates on its own.

## Requirements

- `gcloud` CLI installed and authenticated
- Sufficient IAM permissions for the task at hand (see each subfolder's
  README for specifics)

## Conventions

- Scripts are plain bash, no external dependencies beyond `gcloud` (and
  `bq` where noted).
- Every script accepts arguments rather than hardcoding project/org IDs.
- Output is timestamped and written to an `exports/` (or similar)
  subfolder, which is git-ignored — this repo holds tooling, not
  sensitive output data.
- Folder and script names are lowercase, underscored (`iam_review/`,
  `query_optimization/`, `find_expensive_queries.sh`).
