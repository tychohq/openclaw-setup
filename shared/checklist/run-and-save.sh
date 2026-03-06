#!/usr/bin/env bash
# Run checklist.sh, strip ANSI codes, save to runs/, print the output path.
# Usage: bash run-and-save.sh
#   stdout line 1: path to saved file
#   stdout line 2+: checklist output (ANSI-stripped)
#   exit code: passthrough from checklist.sh

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNS_DIR="$SCRIPT_DIR/runs"
mkdir -p "$RUNS_DIR"

DATESTAMP="$(date +%Y-%m-%d)"
OUTFILE="$RUNS_DIR/checklist-${DATESTAMP}.txt"

# Run checklist, strip ANSI escape codes, tee to file
OUTPUT=$("$SCRIPT_DIR/checklist.sh" 2>&1 | sed 's/\x1b\[[0-9;]*m//g') || EXIT_CODE=$?
EXIT_CODE=${EXIT_CODE:-0}

echo "$OUTPUT" > "$OUTFILE"

# Line 1: file path (for the caller to parse)
echo "FILE:$OUTFILE"
# Rest: the checklist output
echo "$OUTPUT"

exit "$EXIT_CODE"
