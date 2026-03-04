#!/usr/bin/env bash
# =============================================================================
# smoke-test.sh — Verify an OpenClaw deployment can reach its model.
#
# Sends a single agent message through the gateway and checks the response.
# Exits 0 on success, 1 on failure.
#
# Usage:
#   bash smoke-test.sh            # Run against local gateway
#   OPENCLAW_HOME=~/alt bash smoke-test.sh  # Custom home
#
# Requires: openclaw CLI, jq
# =============================================================================
set -euo pipefail

# ── Config ───────────────────────────────────────────────────────────────────

MAX_WAIT=30          # seconds to wait for gateway health
AGENT_TIMEOUT=60     # seconds for the agent call
SESSION_ID="smoke-test-$(date +%s)"

# ── Helpers ──────────────────────────────────────────────────────────────────

log()  { echo "[smoke-test] $1"; }
fail() { echo "[smoke-test] ❌ $1" >&2; }

# ── Preflight: check deps ───────────────────────────────────────────────────

for cmd in openclaw jq; do
  if ! command -v "$cmd" &>/dev/null; then
    fail "$cmd is required but not found in PATH."
    exit 1
  fi
done

# ── Step 1: Wait for gateway to be healthy ───────────────────────────────────

log "Waiting for gateway (up to ${MAX_WAIT}s)..."

elapsed=0
while true; do
  if openclaw health &>/dev/null; then
    break
  fi
  if [ "$elapsed" -ge "$MAX_WAIT" ]; then
    fail "Gateway did not become healthy within ${MAX_WAIT}s."
    echo "  → Is the gateway running? Try: openclaw gateway start"
    echo "  → Check logs: journalctl --user -u openclaw-gateway --since '5 min ago'"
    exit 1
  fi
  sleep 2
  elapsed=$((elapsed + 2))
done

log "Gateway is healthy."

# ── Step 2: Send agent message ───────────────────────────────────────────────

log "Sending smoke test message..."
start_ms=$(date +%s%3N 2>/dev/null || python3 -c 'import time; print(int(time.time()*1000))')

RESULT=""
if ! RESULT=$(openclaw agent \
    --session-id "$SESSION_ID" \
    --message "Reply with exactly: SMOKE_TEST_OK" \
    --json \
    --timeout "$AGENT_TIMEOUT" 2>&1); then
  fail "Agent call failed."
  echo "$RESULT" | head -20 >&2
  echo ""
  echo "  Common fixes:"
  echo "  → Check your API key in ~/.openclaw/.env"
  echo "  → Verify model ID with: openclaw models status"
  echo "  → Check gateway logs: journalctl --user -u openclaw-gateway --since '5 min ago'"
  exit 1
fi

end_ms=$(date +%s%3N 2>/dev/null || python3 -c 'import time; print(int(time.time()*1000))')
duration=$((end_ms - start_ms))

# ── Step 3: Parse response ───────────────────────────────────────────────────

status=$(echo "$RESULT" | jq -r '.status // empty' 2>/dev/null || true)

if [ "$status" != "ok" ]; then
  fail "Agent returned status='${status:-null}' (expected 'ok')."
  error_msg=$(echo "$RESULT" | jq -r '.error // .message // empty' 2>/dev/null || true)
  [ -n "$error_msg" ] && echo "  Error: $error_msg" >&2
  echo ""
  echo "  Common fixes:"
  echo "  → Check your API key in ~/.openclaw/.env"
  echo "  → Verify model ID with: openclaw models status"
  echo "  → Check gateway logs: journalctl --user -u openclaw-gateway --since '5 min ago'"
  exit 1
fi

# Extract response text and model
response_text=$(echo "$RESULT" | jq -r '.result.payloads[0].text // empty' 2>/dev/null || true)
model=$(echo "$RESULT" | jq -r '.result.meta.agentMeta.model // "unknown"' 2>/dev/null || true)

log "✅ Smoke test passed — model '$model' responded in ${duration}ms"
[ -n "$response_text" ] && log "   Response: $(echo "$response_text" | head -1 | cut -c1-80)"

# ── Cleanup ──────────────────────────────────────────────────────────────────

openclaw sessions cleanup &>/dev/null || true

exit 0
