#!/usr/bin/env bash
set -euo pipefail

# ── Integration test: apply all patches against a real openclaw onboard config ──
#
# Creates a temp OpenClaw profile, runs onboard --non-interactive, applies all
# patches, then validates the result is valid JSON with expected keys.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PATCH_CLI="$REPO_ROOT/scripts/openclaw-patch"

PROFILE="test-patch-integration-$$"
PROFILE_DIR="$HOME/.openclaw-$PROFILE"
DEPLOYMENT="${1:-test-instance}"

die()  { echo "FAIL: $*" >&2; exit 1; }
info() { echo "→ $*"; }
ok()   { echo "✓ $*"; }

cleanup() {
  info "Cleaning up profile: $PROFILE"
  rm -rf "$PROFILE_DIR" "$HOME/.openclaw/workspace-$PROFILE" 2>/dev/null || true
}
trap cleanup EXIT

# ── Step 1: Create a fresh baseline config via openclaw onboard ──
info "Creating fresh config via openclaw onboard --non-interactive"
# onboard may exit non-zero due to gateway connection failure (expected)
openclaw --profile "$PROFILE" onboard --non-interactive --accept-risk --auth-choice skip 2>&1 | tail -3 || true

CONFIG="$PROFILE_DIR/openclaw.json"
[[ -f "$CONFIG" ]] || die "onboard didn't create $CONFIG"
ok "Baseline config created: $(wc -l < "$CONFIG") lines"

jq empty "$CONFIG" || die "Baseline config is not valid JSON"
ok "Baseline config is valid JSON"

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

  # tools-config
  '.tools.web.search.provider == "perplexity"'
  '.tools.exec.security == "full"'

  # model-providers
  '.models.mode == "merge"'

  # discord-channel
  '.channels.discord.enabled == true'
  '.channels.discord.groupPolicy == "allowlist"'

  # telegram-channel
  '.channels.telegram.enabled == true'

  # signal-channel
  '.channels.signal.enabled == true'

  # skills-config
  '.skills.install.nodeManager == "bun"'

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

# ── Step 4: Check plugins.allow has channel plugins ──
for plugin in discord telegram signal; do
  if jq -e ".plugins.allow | index(\"$plugin\")" "$CONFIG" >/dev/null 2>&1; then
    ok "plugins.allow contains '$plugin'"
  else
    echo "FAIL: plugins.allow missing '$plugin'"
    FAILED=$((FAILED + 1))
  fi
done

# ── Step 5: Idempotency check ──
info "Re-applying patches (idempotency check)..."
OPENCLAW_HOME="$PROFILE_DIR" OPENCLAW_PATCHES_DIR="$REPO_ROOT" \
  bash "$PATCH_CLI" apply -d "$DEPLOYMENT" 2>&1 | tail -1
ok "Idempotency: re-apply completed"

# ── Summary ──
echo ""
TOTAL=${#CHECKS[@]}
TOTAL=$((TOTAL + 3)) # +3 for plugin checks
PASSED=$((TOTAL - FAILED))
echo "Integration test: $PASSED/$TOTAL checks passed, $FAILED failed"
[[ $FAILED -eq 0 ]] && ok "ALL CHECKS PASSED" || die "$FAILED checks failed"
