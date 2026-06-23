#!/usr/bin/env bash
#
# find_expensive_queries.sh
#
# Exports the most expensive/slowest BigQuery jobs from
# INFORMATION_SCHEMA.JOBS_BY_PROJECT over a lookback window, sorted by
# bytes billed descending.
#
# Output is meant to be pasted/imported into the "Raw - Query History"
# tab of the query optimization tracking workbook.
#
# Usage:
#   ./find_expensive_queries.sh <PROJECT_ID> [DAYS_LOOKBACK] [OUTPUT_DIR]
#
# Example:
#   ./find_expensive_queries.sh amazon-sp-api-openbridge 7 ./exports
#
# Requirements:
#   - gcloud / bq CLI installed and authenticated (gcloud auth login)
#   - Caller needs read access to INFORMATION_SCHEMA.JOBS for the
#     project (e.g. roles/bigquery.resourceViewer or the bq_viewer
#     custom role, provided it includes bigquery.jobs.list)

set -euo pipefail

PROJECT_ID="${1:-}"
DAYS_LOOKBACK="${2:-7}"
OUTPUT_DIR="${3:-./exports}"

if [[ -z "$PROJECT_ID" ]]; then
  echo "Usage: $0 <PROJECT_ID> [DAYS_LOOKBACK] [OUTPUT_DIR]"
  echo "Example: $0 amazon-sp-api-openbridge 7 ./exports"
  exit 1
fi

DATE_TAG="$(date +%Y-%m-%d)"
mkdir -p "$OUTPUT_DIR"

OUT_FILE="${OUTPUT_DIR}/raw_expensive_queries_${DATE_TAG}.csv"

echo "Querying INFORMATION_SCHEMA.JOBS_BY_PROJECT for project: $PROJECT_ID (last ${DAYS_LOOKBACK} days)"

bq query \
  --project_id="$PROJECT_ID" \
  --use_legacy_sql=false \
  --format=csv \
  --max_rows=200 \
  "
  SELECT
    creation_time
    , user_email
    , job_id
    , ROUND(total_bytes_billed / POW(10, 9), 2) AS gb_billed
    , ROUND(total_slot_ms / 1000, 1) AS slot_seconds
    , TIMESTAMP_DIFF(end_time, start_time, SECOND) AS duration_seconds
    , SUBSTR(query, 1, 200) AS query_preview
  FROM \`${PROJECT_ID}\`.\`region-us\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
  WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL ${DAYS_LOOKBACK} DAY)
    AND job_type = 'QUERY'
    AND state = 'DONE'
  ORDER BY total_bytes_billed DESC
  LIMIT 200
  " > "$OUT_FILE"

echo "  -> $OUT_FILE"
echo ""
echo "Done. Next steps:"
echo "  1. Open the query optimization tracking workbook."
echo "  2. Paste contents of $OUT_FILE into a new 'Raw - Query History (${DATE_TAG})' tab."
echo "  3. Add any manually-flagged queries to the same Inventory tab."
echo "  4. Work through best-practices.md for each candidate and mark Action Needed?"