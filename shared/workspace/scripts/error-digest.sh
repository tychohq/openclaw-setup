#!/usr/bin/env bash
# error-digest.sh — Extract new errors from gateway logs since last check.
# Reads the launchd log files (gateway.log / gateway.err.log).
# Filters out noise from agent output that happens to contain error keywords.
# State: cursor file tracks last line count per file.

set -e
trap '' PIPE

LOGS_DIR="${HOME}/.openclaw/logs"
STATE_FILE="${HOME}/.openclaw/workspace/state/error-digest-cursor.json"
ERR_LOG="${LOGS_DIR}/gateway.err.log"
MAIN_LOG="${LOGS_DIR}/gateway.log"

# Initialize state if needed
if [ ! -f "$STATE_FILE" ]; then
  echo '{"errLines": 0, "mainLines": 0}' > "$STATE_FILE"
fi

ERR_CURSOR=$(jq -r '.errLines // 0' "$STATE_FILE")
MAIN_CURSOR=$(jq -r '.mainLines // 0' "$STATE_FILE")

NEW_ERRORS=""
NEW_WARNINGS=""

# --- Error log (stderr) ---
# This contains actual startup failures, port conflicts, etc.
# Filter out repetitive "tip/hint" lines — keep only the substantive errors.
if [ -f "$ERR_LOG" ]; then
  ERR_TOTAL=$(wc -l < "$ERR_LOG" | tr -d ' ')
  if [ "$ERR_TOTAL" -gt "$ERR_CURSOR" ]; then
    NEW_ERRORS=$(tail -n +"$((ERR_CURSOR + 1))" "$ERR_LOG" \
      | grep -v '^\s*$' \
      | grep -v '^Tip:' \
      | grep -v '^Or: launchctl' \
      | grep -v '^If the gateway is supervised' \
      | grep -v 'Stop it first' \
      | grep -v 'Stop it .openclaw gateway stop' \
      | grep -v 'use a different port' \
      | head -500 \
      | sort -u \
      | head -100)
    ERR_CURSOR="$ERR_TOTAL"
  fi
fi

# --- Main log (stdout) ---
# This is a mix of gateway system lines (prefixed with timestamps + [subsystem])
# and raw agent output (self-reflection summaries, cron output, etc.).
#
# Strategy: only match lines that look like gateway system output (have [subsystem] tags)
# AND contain error indicators. This avoids matching agent prose that mentions "error".
if [ -f "$MAIN_LOG" ]; then
  MAIN_TOTAL=$(wc -l < "$MAIN_LOG" | tr -d ' ')
  if [ "$MAIN_TOTAL" -gt "$MAIN_CURSOR" ]; then
    NEW_WARNINGS=$(tail -n +"$((MAIN_CURSOR + 1))" "$MAIN_LOG" \
      | grep -E '^\d{4}-\d{2}-\d{2}T.+\[' \
      | grep -iE '(res ✗|error|fail|crash|ECONNREFUSED|ENOENT|rejected|draining)' \
      | grep -v '0 recovered, 0 failed, 0 skipped' \
      | grep -v '^\s*$' \
      | head -200 \
      | sort -u \
      | head -50)
    MAIN_CURSOR="$MAIN_TOTAL"
  fi
fi

# Update cursor
jq -nc \
  --argjson errLines "$ERR_CURSOR" \
  --argjson mainLines "$MAIN_CURSOR" \
  --arg checkedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{errLines: $errLines, mainLines: $mainLines, checkedAt: $checkedAt}' > "$STATE_FILE"

# Output
if [ -z "$NEW_ERRORS" ] && [ -z "$NEW_WARNINGS" ]; then
  echo "NO_NEW_ERRORS"
  exit 0
fi

echo "=== ERROR LOG (stderr — new since last check) ==="
if [ -n "$NEW_ERRORS" ]; then
  echo "$NEW_ERRORS"
else
  echo "(none)"
fi

echo ""
echo "=== MAIN LOG (stdout — gateway system errors only) ==="
if [ -n "$NEW_WARNINGS" ]; then
  echo "$NEW_WARNINGS"
else
  echo "(none)"
fi
