#!/usr/bin/env bash

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/../../.." && pwd)"
PATCH_CLI="$REPO_ROOT/shared/patches/scripts/openclaw-patch"
FIXTURES_DIR="$REPO_ROOT/shared/patches/tests/fixtures"
PRODUCTION_PATCH_ROOT="$REPO_ROOT/shared/patches"
OPENCLAW_BIN="${OPENCLAW_BIN:-$(command -v openclaw || true)}"

TEST_GATEWAY_PORT=18999
TEST_GATEWAY_URL="ws://127.0.0.1:${TEST_GATEWAY_PORT}"

die() {
  echo "$*" >&2
  exit 1
}

info() {
  echo "→ $*"
}

ok() {
  echo "✓ $*"
}

require_openclaw_bin() {
  [[ -n "$OPENCLAW_BIN" && -x "$OPENCLAW_BIN" ]] || die "openclaw binary not found"
}

write_dummy_env_file() {
  cat > "$TEST_ENV_FILE" <<'EOF_ENV'
ANTHROPIC_API_KEY=dummy-anthropic
OPENAI_API_KEY=dummy-openai
GEMINI_API_KEY=dummy-gemini
DISCORD_TOKEN=dummy-discord-token
DISCORD_OWNER_ID=dummy-discord-owner
DISCORD_GUILD_ID=dummy-discord-guild
TELEGRAM_BOT_TOKEN=dummy-telegram-token
TELEGRAM_OWNER_ID=dummy-telegram-owner
SIGNAL_PHONE_NUMBER=+15555550123
SLACK_BOT_TOKEN=dummy-slack-bot
SLACK_APP_TOKEN=dummy-slack-app
SLACK_OWNER_USER_ID=dummy-slack-owner
EOF_ENV
}

export_dummy_env_file() {
  set -a
  source "$TEST_ENV_FILE"
  set +a
}

copy_tree_contents() {
  local source_dir="$1"
  local dest_dir="$2"

  if [[ -d "$source_dir" ]] && find "$source_dir" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
    cp -R "$source_dir/." "$dest_dir/"
  fi
}

copy_fixture_assets() {
  copy_tree_contents "$FIXTURES_DIR/files" "$TEST_PATCH_ROOT/files"
  copy_tree_contents "$FIXTURES_DIR/skills" "$TEST_PATCH_ROOT/skills"
  copy_tree_contents "$FIXTURES_DIR/extensions" "$TEST_PATCH_ROOT/extensions"
}

setup_test_env() {
  require_openclaw_bin

  local with_gateway=0
  local with_fixtures=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --gateway)
        with_gateway=1
        ;;
      --fixtures)
        with_fixtures=1
        ;;
      *)
        die "unknown setup_test_env option: $1"
        ;;
    esac
    shift
  done

  TEST_PREVIOUS_PWD="$PWD"
  TEST_ORIGINAL_PATH="$PATH"
  TEST_ROOT="$(mktemp -d)"
  TEST_HOME="$TEST_ROOT/openclaw-home"
  TEST_PATCH_ROOT="$TEST_ROOT/patches-repo"
  TEST_ENV_FILE="$TEST_ROOT/.env"
  TEST_GATEWAY_CWD="$TEST_ROOT/gateway-cwd"
  TEST_GATEWAY_LOG="$TEST_ROOT/gateway.log"
  GATEWAY_PID=""

  mkdir -p "$TEST_HOME" "$TEST_PATCH_ROOT/patches" "$TEST_PATCH_ROOT/files" "$TEST_PATCH_ROOT/skills" "$TEST_PATCH_ROOT/extensions" "$TEST_GATEWAY_CWD"
  printf '{}\n' > "$TEST_HOME/openclaw.json"

  export OPENCLAW_HOME="$TEST_HOME"
  export OPENCLAW_CONFIG_PATH="$TEST_HOME/openclaw.json"
  export OPENCLAW_PATCHES_DIR="$TEST_PATCH_ROOT"
  export PATH="$(dirname "$OPENCLAW_BIN"):$TEST_ORIGINAL_PATH"

  write_dummy_env_file

  cd "$TEST_ROOT"

  if [[ $with_fixtures -eq 1 ]]; then
    copy_fixture_assets
  fi

  if [[ $with_gateway -eq 1 ]]; then
    export OPENCLAW_GATEWAY_URL="$TEST_GATEWAY_URL"
    start_test_gateway
    export_dummy_env_file
  else
    unset OPENCLAW_GATEWAY_URL
    export_dummy_env_file
  fi

  trap cleanup_test_env EXIT
}

stop_test_gateway() {
  if [[ -n "${GATEWAY_PID:-}" ]]; then
    kill "$GATEWAY_PID" 2>/dev/null || true
    wait "$GATEWAY_PID" 2>/dev/null || true
  fi

  pkill -f "openclaw gateway run --port ${TEST_GATEWAY_PORT}" 2>/dev/null || true
}

cleanup_test_env() {
  stop_test_gateway

  if [[ -n "${TEST_PREVIOUS_PWD:-}" && -d "${TEST_PREVIOUS_PWD:-}" ]]; then
    cd "$TEST_PREVIOUS_PWD"
  fi

  if [[ -n "${TEST_ROOT:-}" && -d "${TEST_ROOT:-}" ]]; then
    rm -rf "$TEST_ROOT"
  fi

  unset OPENCLAW_HOME OPENCLAW_CONFIG_PATH OPENCLAW_PATCHES_DIR OPENCLAW_GATEWAY_URL
  unset ANTHROPIC_API_KEY OPENAI_API_KEY GEMINI_API_KEY DISCORD_TOKEN DISCORD_OWNER_ID DISCORD_GUILD_ID
  unset TELEGRAM_BOT_TOKEN TELEGRAM_OWNER_ID SIGNAL_PHONE_NUMBER SLACK_BOT_TOKEN SLACK_APP_TOKEN SLACK_OWNER_USER_ID
  export PATH="${TEST_ORIGINAL_PATH:-$PATH}"
}

pids_listening_on_port() {
  local port="$1"

  if command -v lsof >/dev/null 2>&1; then
    lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null | sort -u || true
    return 0
  fi

  if command -v fuser >/dev/null 2>&1; then
    fuser -n tcp "$port" 2>/dev/null | tr ' ' '\n' | sort -u || true
    return 0
  fi
}

clear_listeners_on_port() {
  local port="$1"
  local pids
  local attempt

  pids="$(pids_listening_on_port "$port")"
  [[ -z "$pids" ]] && return 0

  info "Stopping leftover gateway on port $port"
  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    kill "$pid" 2>/dev/null || true
  done <<< "$pids"

  for attempt in $(seq 1 10); do
    sleep 0.2
    pids="$(pids_listening_on_port "$port")"
    [[ -z "$pids" ]] && return 0
  done

  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    kill -9 "$pid" 2>/dev/null || true
  done <<< "$pids"
}

start_test_gateway() {
  clear_listeners_on_port "$TEST_GATEWAY_PORT"

  (
    cd "$TEST_GATEWAY_CWD"
    "$OPENCLAW_BIN" gateway run \
      --port "$TEST_GATEWAY_PORT" \
      --bind loopback \
      --auth none \
      --allow-unconfigured \
      >"$TEST_GATEWAY_LOG" 2>&1
  ) &
  GATEWAY_PID=$!
  disown "$GATEWAY_PID" 2>/dev/null || true

  wait_for_gateway
}

wait_for_gateway() {
  local attempt
  for attempt in $(seq 1 50); do
    if OPENCLAW_GATEWAY_URL="$OPENCLAW_GATEWAY_URL" \
      "$OPENCLAW_BIN" cron list --json --timeout 1000 >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.2
  done

  if [[ -f "$TEST_GATEWAY_LOG" ]]; then
    cat "$TEST_GATEWAY_LOG" >&2
  fi
  die "gateway did not become ready on ${OPENCLAW_GATEWAY_URL}"
}

load_fixture_patch() {
  local fixture_name="$1"
  cp "$FIXTURES_DIR/$fixture_name" "$TEST_PATCH_ROOT/patches/"
}

use_production_patches_dir() {
  export OPENCLAW_PATCHES_DIR="$PRODUCTION_PATCH_ROOT"
}

apply_patches() {
  local deployment="${1:-test-instance}"
  cd "$TEST_ROOT"
  OPENCLAW_HOME="$OPENCLAW_HOME" \
    OPENCLAW_CONFIG_PATH="$OPENCLAW_CONFIG_PATH" \
    OPENCLAW_PATCHES_DIR="$OPENCLAW_PATCHES_DIR" \
    bash "$PATCH_CLI" apply -d "$deployment"
}

openclaw_config_set() {
  local path="$1"
  local value="$2"
  cd "$TEST_ROOT"
  OPENCLAW_HOME="$OPENCLAW_HOME" \
    OPENCLAW_CONFIG_PATH="$OPENCLAW_CONFIG_PATH" \
    "$OPENCLAW_BIN" config set "$path" "$value"
}

cron_list_json() {
  cd "$TEST_ROOT"
  OPENCLAW_GATEWAY_URL="$OPENCLAW_GATEWAY_URL" \
    "$OPENCLAW_BIN" cron list --json --timeout 1000
}

applied_patch_count() {
  jq 'keys | length' "$OPENCLAW_HOME/patches/applied.json"
}

extension_install_dir() {
  local extension_name="$1"
  local direct_path="$OPENCLAW_HOME/extensions/$extension_name"
  local nested_path="$OPENCLAW_HOME/.openclaw/extensions/$extension_name"

  if [[ -d "$direct_path" ]]; then
    echo "$direct_path"
    return 0
  fi

  if [[ -d "$nested_path" ]]; then
    echo "$nested_path"
    return 0
  fi

  return 1
}
