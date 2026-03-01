# uv / uvx (Python)

## First-Run Latency

`uv run` in a project can take 10-15+ seconds on first invocation (resolving/installing deps). When running `uv run` via `exec`, set `yieldMs: 20000` or higher to avoid burning API calls polling an empty process. Subsequent runs in the same project are fast.

## Long-Running Analytical Queries

Heavy data processing scripts (DuckDB, pandas, etc.) can take 2-10+ minutes. Set `yieldMs: 600000` (10 min) and `timeout: 900` to avoid tight `process poll` loops that burn API calls on "(no new output)". If a query estimates "~12 hours remaining", it's likely a bad query plan (e.g., `OR` join on 354M rows) — kill it and fix the query rather than waiting.

## Python Heredoc + Emoji

Unicode emoji in Python heredoc strings (`<< 'EOF'`) can cause `SyntaxError: invalid character`. Write to a temp `.py` file instead, or avoid emoji in heredoc code.
