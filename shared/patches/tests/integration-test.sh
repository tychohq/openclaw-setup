#!/usr/bin/env bash
set -euo pipefail

# ── Integration test: apply all patches against a minimal baseline config ────
#
# Creates a temp dir with a minimal openclaw.json, mocks the openclaw CLI,
# applies all patches, then validates the result is valid JSON with expected keys.
# Fully isolated — no files created in $HOME.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PATCH_CLI="$REPO_ROOT/scripts/openclaw-patch"

DEPLOYMENT="${1:-test-instance}"

die()  { echo "FAIL: $*" >&2; exit 1; }
info() { echo "→ $*"; }
ok()   { echo "✓ $*"; }

PROFILE_DIR="$(mktemp -d)"
MOCK_BIN="$(mktemp -d)"

cleanup() {
  info "Cleaning up: $PROFILE_DIR"
  rm -rf "$PROFILE_DIR" "$MOCK_BIN" 2>/dev/null || true
}
trap cleanup EXIT

# ── Mock openclaw binary ──
# Handles `plugins enable` (jq merge), `config get` (jq getpath),
# and `config set` (jq setpath) so the integration test doesn't
# need the real openclaw CLI.
cat > "$MOCK_BIN/openclaw" << 'MOCK'
#!/usr/bin/env bash
CONFIG="${OPENCLAW_CONFIG_PATH:-$OPENCLAW_HOME/openclaw.json}"

if [[ "${1:-}" == "plugins" && "${2:-}" == "enable" ]]; then
  plugin="${3:?missing plugin name}"
  tmp=$(mktemp)
  jq --arg p "$plugin" '.plugins.entries[$p] = {"enabled": true}' "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
  echo "Enabled plugin \"$plugin\"."
  exit 0
fi

if [[ "${1:-}" == "config" && "${2:-}" == "get" ]]; then
  path="${3:?missing path}"
  jq_path=$(echo "$path" | sed 's/\./","/g' | sed 's/^/["/' | sed 's/$/"]/')
  jq "getpath($jq_path)" "$CONFIG"
  exit 0
fi

if [[ "${1:-}" == "config" && "${2:-}" == "set" ]]; then
  path="${3:?missing path}"
  value="${4:?missing value}"
  tmp=$(mktemp)
  # Convert dot path to jq path array: "a.b.c" -> ["a","b","c"]
  jq_path=$(echo "$path" | sed 's/\./","/g' | sed 's/^/["/' | sed 's/$/"]/')
  # Try to parse value as JSON first, fall back to string
  if echo "$value" | jq empty 2>/dev/null; then
    jq --argjson v "$value" "setpath($jq_path; \$v)" "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
  else
    jq --arg v "$value" "setpath($jq_path; \$v)" "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
  fi
  echo "Updated $path."
  exit 0
fi

if [[ "${1:-}" == "cron" && "${2:-}" == "list" ]]; then
  echo "[]"
  exit 0
fi

# Log anything else
echo "mock-openclaw: $*" >> "${OPENCLAW_HOME:-/tmp}/mock-openclaw-calls.txt"
MOCK
chmod +x "$MOCK_BIN/openclaw"
export PATH="$MOCK_BIN:$PATH"

# ── Step 1: Create a minimal baseline config ──
CONFIG="$PROFILE_DIR/openclaw.json"
info "Creating baseline config in $PROFILE_DIR"

cat > "$CONFIG" << 'BASELINE'
{
  "version": 1,
  "source": "test",
  "agents": {},
  "channels": {},
  "models": {},
  "plugins": {
    "entries": {}
  },
  "session": {},
  "tools": {},
  "skills": {},
  "memory": {},
  "hooks": {}
}
BASELINE

ok "Baseline config created"

jq empty "$CONFIG" || die "Baseline config is not valid JSON"
ok "Baseline config is valid JSON"

# ── Step 1.5: Set dummy env vars ──
info "Setting dummy env vars for requires gates"
export ANTHROPIC_API_KEY="test-dummy"
export OPENAI_API_KEY="test-dummy"
export DISCORD_TOKEN="test-dummy"
export DISCORD_OWNER_ID="test-dummy"
export DISCORD_GUILD_ID="test-dummy"
export TELEGRAM_BOT_TOKEN="test-dummy"
export TELEGRAM_OWNER_ID="test-dummy"
export SIGNAL_PHONE_NUMBER="test-dummy"
export SLACK_BOT_TOKEN="test-dummy"
export SLACK_APP_TOKEN="test-dummy"
export SLACK_OWNER_USER_ID="test-dummy"
export PERPLEXITY_API_KEY="test-dummy"

# ── Step 2: Apply all patches ──
info "Applying all patches with deployment=$DEPLOYMENT"
OPENCLAW_HOME="$PROFILE_DIR" OPENCLAW_PATCHES_DIR="$REPO_ROOT" \
  bash "$PATCH_CLI" apply -d "$DEPLOYMENT" 2>&1

# ── Step 3: Validate result ──
info "Validating patched config..."

jq empty "$CONFIG" || die "Patched config is not valid JSON!"
ok "Patched config is valid JSON"

# Check key fields from each patch
CHECKS=(
  # agent-defaults
  '.agents.defaults.model.primary == "anthropic/claude-opus-4-6"'
  '.agents.defaults.compaction.reserveTokensFloor == 80000'
  '.agents.defaults.heartbeat.every == "1h"'

  # memory-config
  '.memory.backend == "builtin"'
  '.hooks.internal.enabled == true'

  # session-config
  '.session.dmScope == "per-channel-peer"'
  '.session.reset.mode == "idle"'
  '.messages.queue.mode == "steer"'

  # web-search
  '.tools.web.search.provider == "perplexity"'

  # agent-permissions
  '.tools.exec.security == "full"'

  # agent-collaboration
  '.tools.sessions.visibility == "all"'

  # model-providers
  '.models.mode == "merge"'

  # discord-channel
  '.plugins.entries.discord.enabled == true'
  '.channels.discord.enabled == true'
  '.channels.discord.groupPolicy == "allowlist"'
  '(.channels.discord.allowFrom | length) > 0'

  # telegram-channel
  '.plugins.entries.telegram.enabled == true'
  '.channels.telegram.enabled == true'
  '(.channels.telegram.allowFrom | length) > 0'

  # signal-channel
  '.plugins.entries.signal.enabled == true'
  '.channels.signal.enabled == true'
  '(.channels.signal.allowFrom | length) > 0'

  # slack-channel
  '(.channels.slack.allowFrom | length) > 0'

  # skills-config
  '(.skills.load.extraDirs | length) > 0'

  # browser-config
  '.browser.headless == false'

  # security-config
  '.discovery.wideArea.enabled == false'
  '.discovery.mdns.mode == "minimal"'
)

FAILED=0
for check in "${CHECKS[@]}"; do
  if jq -e "$check" "$CONFIG" >/dev/null 2>&1; then
    ok "$check"
  else
    echo "FAIL: $check"
    actual=$(jq "$(echo "$check" | sed 's/ ==.*//')" "$CONFIG" 2>&1)
    echo "  got: $actual"
    FAILED=$((FAILED + 1))
  fi
done

# ── Step 4: Idempotency check ──
info "Re-applying patches (idempotency check)..."
OPENCLAW_HOME="$PROFILE_DIR" OPENCLAW_PATCHES_DIR="$REPO_ROOT" \
  bash "$PATCH_CLI" apply -d "$DEPLOYMENT" 2>&1 | tail -1
ok "Idempotency: re-apply completed"

# ── Step 5: Requires gate test ──
info "Testing requires gate (graceful skip)..."
unset ANTHROPIC_API_KEY
echo "{}" > "$PROFILE_DIR/patches/applied.json"
REQ_OUTPUT="$(OPENCLAW_HOME="$PROFILE_DIR" OPENCLAW_PATCHES_DIR="$REPO_ROOT" bash "$PATCH_CLI" apply -d "$DEPLOYMENT" 2>&1)"
echo "$REQ_OUTPUT" | grep -q "skipped (missing env)" || die "Requires gate did not produce skip summary"
echo "$REQ_OUTPUT" | grep -qi "skipping model-providers" || die "model-providers was not skipped"
ok "Requires gate: graceful skip confirmed"

# ── Summary ──
echo ""
TOTAL=${#CHECKS[@]}
PASSED=$((TOTAL - FAILED))
echo "Integration test: $PASSED/$TOTAL checks passed, $FAILED failed"
[[ $FAILED -eq 0 ]] && ok "ALL CHECKS PASSED" || die "$FAILED checks failed"
