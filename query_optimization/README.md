# Query Optimization

Recurring process for identifying slow or expensive BigQuery queries,
reviewing them against query-writing best practices, and tracking what
was changed and why. Scripts only **gather** data — decisions and
changes happen manually and get logged afterward.

No fixed review cadence yet. This folder structures the workbook and
process so a cadence (e.g. monthly, quarterly, or sprint-aligned) can be
added once we have a sense of volume.

## What this does and doesn't do

`find_expensive_queries.sh` only **reads** query history from
`INFORMATION_SCHEMA.JOBS` — it makes no changes to BigQuery. The actual
review (deciding what's worth optimizing, applying changes, validating
results) happens in the tracking workbook and directly in BigQuery /
the relevant pipeline code — not here.

## Where candidates come from

Two sources feed the review:

1. **Automatic** — `find_expensive_queries.sh` pulls the highest
   bytes-billed / longest-running queries from `INFORMATION_SCHEMA.JOBS`
   for a given lookback window.
2. **Manual** — anyone on the team can flag a query themselves (a slow
   dashboard, a pipeline step that's taking too long, a one-off query
   that felt sluggish) and add it directly to the workbook's Inventory
   tab with a note on why it was flagged.

Both land in the same Inventory tab so nothing is lost between the two
intake paths.

## Usage

```bash
./find_expensive_queries.sh <PROJECT_ID> [DAYS_LOOKBACK] [OUTPUT_DIR]
```

Example:

```bash
./find_expensive_queries.sh amazon-sp-api-openbridge 7 ./exports
```

This produces one timestamped file:

- `exports/raw_expensive_queries_<DATE>.csv`

Each row is one job: query text, bytes billed, slot time, duration,
user, and creation time, sorted by bytes billed descending.

## Required access

The account running this needs read access to
`INFORMATION_SCHEMA.JOBS` (or `JOBS_BY_PROJECT` / `JOBS_BY_ORGANIZATION`
depending on scope) — covered by `roles/bigquery.resourceViewer` or
higher, or the custom `bq_viewer` role from the IAM review if it
includes `bigquery.jobs.list`.

## Process (cadence TBD)

1. Run `find_expensive_queries.sh` for the lookback window.
2. Paste the raw output into a new dated tab in the tracking workbook
   (`Raw - Query History`).
3. Add any manually-flagged queries to the same Inventory tab.
4. For each candidate, work through the relevant checks in
   `best-practices.md` and mark **Action Needed?** (Yes / No / Monitor),
   with notes.
5. For anything marked **Yes**, make the change in the source
   (pipeline SQL, view definition, dashboard query) and re-measure using
   the timing technique in `best-practices.md` to confirm improvement.
6. Log the before/after in the workbook's `Changes Log` tab (date,
   query/source, change made, before metric, after metric, who
   approved).