#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-lib.sh"

DEPLOYMENT="${1:-test-instance}"

assert_config_check() {
  local check="$1"
  if jq -e "$check" "$OPENCLAW_CONFIG_PATH" >/dev/null 2>&1; then
    ok "$check"
  else
    jq '.' "$OPENCLAW_CONFIG_PATH" >&2
    die "failed config assertion: $check"
  fi
}

info "Setting up isolated OpenClaw home"
setup_test_env --gateway
use_production_patches_dir

info "Applying production patches for deployment=$DEPLOYMENT"
first_output="$(apply_patches "$DEPLOYMENT")"
echo "$first_output"

jq empty "$OPENCLAW_CONFIG_PATH" >/dev/null
ok 'Patched config is valid JSON'

CHECKS=(
  '.agents.defaults.model.primary == "anthropic/claude-opus-4-6"'
  '.agents.defaults.compaction.reserveTokensFloor == 80000'
  '.agents.defaults.heartbeat.every == "1h"'
  '.memory.backend == "builtin"'
  '.hooks.internal.enabled == true'
  '.session.dmScope == "per-channel-peer"'
  '.session.reset.mode == "idle"'
  '.messages.queue.mode == "steer"'
  '.tools.sessions.visibility == "all"'
  '.tools.exec.security == "full"'
  '.models.mode == "merge"'
  '.plugins.entries.discord.enabled == true'
  '.plugins.entries.telegram.enabled == true'
  '.plugins.entries.signal.enabled == true'
  '.plugins.entries.slack.enabled == true'
  '.channels.discord.enabled == true'
  '.channels.discord.groupPolicy == "allowlist"'
  '(.channels.discord.allowFrom | length) > 0'
  '.channels.telegram.enabled == true'
  '(.channels.telegram.allowFrom | length) > 0'
  '.channels.signal.enabled == true'
  '(.channels.signal.allowFrom | length) > 0'
  '.channels.slack.enabled == true'
  '(.channels.slack.allowFrom | length) > 0'
  '.skills.load.extraDirs | index("~/.agents/skills") != null'
  '.browser.headless == false'
  '.discovery.wideArea.enabled == false'
  '.discovery.mdns.mode == "minimal"'
  '.tools.media.audio.enabled == true'
  '.tools.media.audio.models | map(select(.provider == "openai" and .model == "whisper-1")) | length == 1'
  '.tools.web.search.provider == "gemini"'
)

for check in "${CHECKS[@]}"; do
  assert_config_check "$check"
done

extension_dir="$(extension_install_dir inject-datetime)"
[[ -f "$extension_dir/openclaw.plugin.json" ]]
ok "inject-datetime extension installed at $extension_dir"

applied_before="$(applied_patch_count)"
second_output="$(apply_patches "$DEPLOYMENT")"
echo "$second_output"
echo "$second_output" | grep -q 'Summary: 0 applied'
applied_after="$(applied_patch_count)"
[[ "$applied_before" == "$applied_after" ]]

jq -e '.skills.load.extraDirs | map(select(. == "~/.agents/skills")) | length == 1' "$OPENCLAW_CONFIG_PATH" >/dev/null
jq -e '.plugins.entries["inject-datetime"].enabled == true' "$OPENCLAW_CONFIG_PATH" >/dev/null

ok 'Idempotency checks passed'
ok 'Integration test passed'
