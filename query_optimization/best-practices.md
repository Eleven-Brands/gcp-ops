# BigQuery Query Optimization — Best Practices

Reference for writing and reviewing efficient BigQuery SQL, plus the
manual timing technique for measuring query performance directly via
the REST API. Used alongside the process in `README.md` and the
tracking workbook.

---

## 1. Measuring query speed (REST API timing)

Adapted from *BigQuery: The Definitive Guide*. Useful for confirming
whether a change actually improved performance — run the query N times
before and after a change, compare total/average time.

### Prerequisites

1. `gcloud` installed and on PATH (`gcloud --version` to check).
2. Authenticated:
   ```bash
   gcloud auth login
   gcloud auth application-default login
   gcloud config set project YOUR_PROJECT_ID
   ```
   `auth login` authenticates the CLI itself; `auth application-default
   login` is a separate credential used by REST calls — both are
   needed.

### Step 1 — Load the SQL into a variable

```bash
read -d '' QUERY_TEXT << EOF
SELECT
  asin
  , AVG(available_quantity) as qty
  , COUNT(sku) as num_skus
FROM \`amazon-sp-api-openbridge.2_Silver_Inventory.vw_full_fba_manage_inventory_real_time\`
GROUP BY asin
ORDER BY num_skus DESC
LIMIT 5
EOF
```

- `read -d ''` reads multi-line input into a variable instead of
  stopping at the first newline.
- `<< EOF ... EOF` is a heredoc — everything between the markers is fed
  in literally, line breaks included.
- Backticks in the table path are escaped (`\`...\``) since backtick
  has special meaning in bash (command substitution) as well as in
  BigQuery SQL (quoting table paths).

**Type the `read -d '' ... << EOF` line by hand rather than pasting it
from a book/PDF/photo** — typeset text often swaps a plain hyphen for a
Unicode dash, which bash can't parse and fails with a cryptic
`command not found` error. The body (the SQL itself) is safe to paste.

### Step 2 — Build the JSON request body

```bash
read -d '' request << EOF
{
  "useLegacySql": false,
  "useQueryCache": false,
  "query": \"${QUERY_TEXT}\"
}
EOF
```

- `useQueryCache: false` is the important flag here — without it,
  repeat runs mostly measure cache lookup speed, not real execution,
  which defeats the point of timing.

### Step 3 — Get an access token and project ID

```bash
access_token=$(gcloud auth application-default print-access-token)
PROJECT=$(gcloud config get-value project)
```

The token expires after about an hour — rerun this line if later calls
return `401`.

### Step 4 — Run the query N times and time it

```bash
NUM_TIMES=10

time for i in $(seq 1 $NUM_TIMES); do
  echo -en "\r ... $i / $NUM_TIMES ..."
  curl --silent \
    -H "Authorization: Bearer ${access_token}" \
    -H "Content-Type: application/json" \
    -X POST \
    -d "$request" \
    "https://bigquery.googleapis.com/bigquery/v2/projects/${PROJECT}/queries" > /dev/null
done
```

- `-X POST` sets the HTTP method — not `-H POST`, which would add a
  garbage header instead and silently break the request.
- `> /dev/null` discards the response body; only the `real` time at the
  end matters. Divide by `NUM_TIMES` for average time per query.

---

## 2. Query-writing checks

Run through these when reviewing a flagged query. Not all apply to
every query — use judgment.

### Scan reduction (the biggest lever in on-demand pricing)

- **Avoid `SELECT *`.** BigQuery is columnar — every column you select
  is scanned and billed, whether you use it or not. Select only the
  columns actually needed.
- **Filter on partitioned/clustered columns where possible**, ideally
  as early as possible in the query (in the `WHERE` clause, not buried
  in a subquery or applied after a join).
- **Check partition pruning is actually happening** — a filter on a
  partitioned column using a function (e.g. `DATE(timestamp_col) =
  ...`) can prevent pruning; compare against the raw column directly
  where possible.
- **Use `_PARTITIONTIME` / partition filters on large ingestion-time
  partitioned tables** if the table requires a partition filter — confirm
  this isn't being bypassed accidentally.

### Joins

- **Join smaller tables first / filter before joining** — reduce row
  counts as early as possible rather than joining full tables and
  filtering after.
- **Watch for fan-out joins** (one-to-many relationships that multiply
  row counts unexpectedly) — verify expected row counts before and
  after a join, especially before aggregating.
- **Avoid `CROSS JOIN`** unless deliberate; an accidental cross join
  (e.g. missing join condition) silently explodes both scan size and
  output rows.

### Aggregation and window functions

- **Push `GROUP BY` / aggregation as early as possible** in multi-step
  queries (CTEs), rather than aggregating a fully joined, wide result.
- **Be cautious with window functions over large unpartitioned
  windows** (`OVER ()` with no `PARTITION BY`) — this can force a single
  massive sort/scan.

### Query structure

- **Materialize expensive repeated subqueries** — if the same
  expensive CTE or subquery is referenced multiple times, consider a
  temp table or materialized view instead of letting BigQuery
  re-evaluate it.
- **Check `UNION` vs `UNION ALL`** — `UNION` deduplicates (extra
  processing); use `UNION ALL` unless deduplication is actually needed.
- **Avoid unnecessary `ORDER BY`** on large intermediate results —
  sorting is expensive; only sort the final output, not intermediate
  CTEs.

### Caching and repeated runs

- **Check `useQueryCache`** isn't masking a slow query in production
  dashboards — a cached "fast" query may still be slow on first run /
  cache miss, which matters if the underlying data changes frequently.

---

## 3. What to capture per reviewed query

When logging a query in the Inventory tab, capture:

- Query text (or link to source: pipeline file, view name, dashboard)
- Bytes billed / slot time (from `find_expensive_queries.sh` or
  manual flag)
- Suspected issue (from the checks above)
- Action taken
- Before/after timing (using the REST API technique above) or
  before/after bytes billed
- Who reviewed, who approved the change