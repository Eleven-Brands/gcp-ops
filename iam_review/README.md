# IAM Review

Recurring process for reviewing GCP IAM permissions across the project
and the organization, identifying excessive or unused access, and
keeping a tracked history of what was changed and why.

Originates from ClickUp task `86ady067q`.

## What this does and doesn't do

This script only **exports** the current IAM bindings — it is read-only
and makes no changes to GCP. The actual review (deciding what's
necessary, validating with stakeholders, applying changes) happens in
the tracking workbook and directly in the GCP IAM console — not here.

## Using the script

### 1. Make the script executable (Mac/Linux only, first time only)

```bash
chmod +x iam_review/export_iam.sh
```

On Windows, skip this step — the script runs via Git Bash regardless of
the execute permission bit.

### 2. Run the export

```bash
./export_iam.sh <PROJECT_ID> <ORG_ID> [OUTPUT_DIR]
```

Example:

```bash
./export_iam.sh amazon-sp-api-openbridge 365485448420 ./exports
```

This produces two timestamped files in `./exports/` (or your chosen output dir):

- `raw_project_iam_<DATE>.txt` — project-level bindings
- `raw_org_iam_<DATE>.txt` — org-level bindings

Each is a flattened `role | member` table, one row per binding.

### 3. Paste into the workbook

Open the IAM review workbook — located at:

```bash
G:\Shared drives\OrganiHaus\3.1 - OH Data & Reports\gcp_service_accounts
```

Open the IAM review workbook (linked in the Drive Output field of ClickUp
task `86ady067q`). For each file:

- Create a new tab named `Raw - Project IAM (YYYY-MM-DD)`
- Paste the contents of `raw_project_iam_<DATE>.txt`
- Create a new tab named `Raw - Org IAM (YYYY-MM-DD)`
- Paste the contents of `raw_org_iam_<DATE>.txt`

### 4. Review the Inventory tab

Compare the new bindings against the previous quarter's Inventory tab.
Flag any new, removed, or changed bindings. For each binding, mark
**Necessary?** (Yes / No / Needs Check) with notes and reviewer name.

### 5. Validate and apply changes

For anything marked **No**, validate with the responsible person before
revoking. Apply approved changes directly in GCP IAM console.

### 6. Log and close

- Log every change in the workbook's `Changes Log` tab
- Run `BQ Job Audit - User Activity` saved query (BigQuery console,
  project `amazon-sp-api-openbridge`) for each user to validate whether
  their access is actually being exercised
- Add a row to `Review History` summarizing the run and set the next
  review due date (~3 months out)
- Create a new ClickUp task for the next quarterly review

## Managing custom roles via CLI

### Create a new role

```bash
gcloud iam roles create <ROLE_ID> \
  --organization=<ORG_ID> \
  --title="<Title>" \
  --description="<Description>" \
  --permissions=<permission1>,<permission2>,<permission3> \
  --stage=GA
```

### Update an existing role (add/remove permissions)

```bash
gcloud iam roles update <ROLE_ID> \
  --organization=<ORG_ID> \
  --add-permissions=<permission1>,<permission2> \
  --remove-permissions=<permission3>
```

### Assign a role to a principal

```bash
gcloud organizations add-iam-policy-binding <ORG_ID> \
  --member="user:<email>" \
  --role="organizations/<ORG_ID>/roles/<ROLE_ID>"
```

### Disable (deprecate) a role

```bash
gcloud iam roles update <ROLE_ID> \
  --organization=<ORG_ID> \
  --stage=DISABLED
```

Run all commands from Git Bash on Windows.


## Required access

The account running this script needs:

- `resourcemanager.projects.getIamPolicy` on the target project
- `resourcemanager.organizations.getIamPolicy` on the target org

These are covered by the custom `iam_admin` role, or the predefined
`roles/iam.securityReviewer` for read-only access.

## Custom role system

As of the first review (2026-06-22), all principals have been migrated
off predefined roles onto a modular custom role system defined at the org
level (`365485448420`). Roles are independent and single-purpose — each
grants exactly one capability, composable based on actual use case.

The system covers five domains:

- **BigQuery** (`bq_*`) — 6 roles: viewer, job_runner, writer, creator, updater, destructor
- **Billing** (`billing_*`) — 2 roles: viewer, editor
- **IAM** — 2 roles: iam_admin, role_manager
- **Service Accounts** (`sa_*`) — 5 roles: viewer, manager, key_manager, impersonator, iam_editor
- **API Credentials** — 1 role: api_credentials_manager

The source of truth for role definitions and current assignments is the
IAM review workbook (single tab: `Role Reference`, covering all five
domains) and the GCP console (IAM & Admin → Roles, org level
`365485448420`).

## Notes from the first run (2026-06-19)

- Group membership (e.g. `gcp-security-admins@11brands.com`) shows up as
  the group principal only — `gcloud get-iam-policy` does not expand group
  membership. A separate pull from Google Workspace/Admin Console is needed
  to see who is actually inside each group.
- A permission error on `get-iam-policy` may just mean the project ID was
  typed incorrectly — GCP returns a generic permission error for nonexistent
  projects. Double-check the ID before assuming an access problem.

## Notes from the first run (2026-06-22)

- BigQuery console saved queries section requires `dataform.repositories.list`
  in addition to `bigquery.savedqueries.*`. Add to `bq_viewer` if users need
  to see the Queries section in the BQ console.
- Power BI and Google Sheets connectors require `bigquery.readsessions.create`
  and `bigquery.readsessions.getData` in addition to `bigquery.jobs.create`.
  These are included in `bq_job_runner`.
- `INFORMATION_SCHEMA.JOBS_BY_PROJECT` requires `bigquery.jobs.listAll` —
  add to `bq_job_runner` if users need project-wide job history visibility.
- `roles/owner` does not include `resourcemanager.folders.*` permissions.
  If the org does not use folders, `roles/resourcemanager.organizationAdmin`
  is not needed.
- Granting `role_manager` + `iam_admin` to the same principal enables
  privilege escalation. Never grant both to untrusted principals.