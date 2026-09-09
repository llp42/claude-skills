---
name: csv-summary
description: MUST be used whenever the user asks to summarize, profile, or get statistics on a CSV file (row/column counts, nulls, ranges, distributions). Always invoke this instead of manually parsing the CSV yourself.
argument-hint: [file]
allowed-tools: Read, Bash(python3:*), Bash(wc:*), Bash(head:*)
model: haiku
context: fork
agent: general-purpose
background: false
---

Target file: `$1`

1. If `$1` is empty, state that a file path is required and stop.
2. Run `wc -l "$1"` to get the line count.
   - If the file cannot be read or does not look like valid CSV (no consistent delimiter across lines — check with `head -5 "$1"`), say so plainly and stop.
   - If under ~5000 lines, read the file directly with Read and parse it.
   - Otherwise, compute stats with a `python3 -c "..."` one-liner using the standard `csv` module (do not use pandas, do not load all rows into memory/conversation).
3. Compute and report:
   - Total row count (excluding header)
   - Column names
   - Inferred type per column (numeric / text / date / boolean), best-effort from a sample of values
   - Null/empty-value count per column
   - For numeric columns: min, max, mean
   - For columns with under ~20 distinct values: value counts
4. Present the report as a compact table/list. Do not dump raw row data.
