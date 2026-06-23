#!/usr/bin/env bash
#
# export_iam.sh
#
# Exports GCP IAM policy bindings at both project and organization level,
# flattened into readable role/member tables, with timestamped filenames.
#
# Output is meant to be pasted/imported into the "Raw - Project IAM" and
# "Raw - Org IAM" tabs of the IAM review tracking workbook each time this
# runs (suggested cadence: quarterly).
#
# Usage:
#   ./export_iam.sh <PROJECT_ID> <ORG_ID> [OUTPUT_DIR]
#
# Example:
#   ./export_iam.sh amazon-sp-api-openbridge 365485448420 ./exports
#
# Requirements:
#   - gcloud CLI installed and authenticated (gcloud auth login)
#   - Caller needs resourcemanager.projects.getIamPolicy on the project
#     and resourcemanager.organizations.getIamPolicy on the org
#     (e.g. roles/owner, roles/resourcemanager.organizationAdmin, or
#     roles/iam.securityReviewer for read-only access)

set -euo pipefail

PROJECT_ID="${1:-}"
ORG_ID="${2:-}"
OUTPUT_DIR="${3:-./exports}"

if [[ -z "$PROJECT_ID" || -z "$ORG_ID" ]]; then
  echo "Usage: $0 <PROJECT_ID> <ORG_ID> [OUTPUT_DIR]"
  echo "Example: $0 amazon-sp-api-openbridge 365485448420 ./exports"
  exit 1
fi

DATE_TAG="$(date +%Y-%m-%d)"
mkdir -p "$OUTPUT_DIR"

PROJECT_OUT="${OUTPUT_DIR}/raw_project_iam_${DATE_TAG}.txt"
ORG_OUT="${OUTPUT_DIR}/raw_org_iam_${DATE_TAG}.txt"

echo "Exporting project-level IAM bindings for: $PROJECT_ID"
gcloud projects get-iam-policy "$PROJECT_ID" \
  --flatten="bindings[].members" \
  --format="table(bindings.role,bindings.members)" \
  > "$PROJECT_OUT"
echo "  -> $PROJECT_OUT"

echo "Exporting organization-level IAM bindings for: $ORG_ID"
gcloud organizations get-iam-policy "$ORG_ID" \
  --flatten="bindings[].members" \
  --format="table(bindings.role,bindings.members)" \
  > "$ORG_OUT"
echo "  -> $ORG_OUT"

echo ""
echo "Done. Next steps:"
echo "  1. Open the IAM review workbook."
echo "  2. Paste contents of $PROJECT_OUT into a new 'Raw - Project IAM (${DATE_TAG})' tab."
echo "  3. Paste contents of $ORG_OUT into a new 'Raw - Org IAM (${DATE_TAG})' tab."
echo "  4. Compare against the previous quarter's Inventory tab and flag any new/changed bindings."