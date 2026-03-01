#!/usr/bin/env bash
# =============================================================================
# setup-openclaw.sh — Non-interactive OpenClaw configuration
#
# Places config + env files, installs the daemon, and starts the gateway.
# Idempotent — safe to re-run.
#
# Usage:
#   ./scripts/setup-openclaw.sh --config openclaw-secrets.json --env openclaw-secrets.env --auth-profiles openclaw-auth-profiles.json
#   ./scripts/setup-openclaw.sh --config openclaw-secrets.json  # env vars inline in config
#   ./scripts/setup-openclaw.sh --check                         # verify existing install
#
# The secrets files are YOUR filled-in copies of the templates in config/.
# They should NOT be committed to git (they're in .gitignore).
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
OPENCLAW_DIR="$HOME/.openclaw"

CONFIG_FILE=""
ENV_FILE=""
AUTH_PROFILES_FILE=""
CHECK_ONLY=false
DRY_RUN=false

# ── Parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)         CONFIG_FILE="$2"; shift 2 ;;
    --env)            ENV_FILE="$2"; shift 2 ;;
    --auth-profiles)  AUTH_PROFILES_FILE="$2"; shift 2 ;;
    --check)          CHECK_ONLY=true; shift ;;
    --dry-run)        DRY_RUN=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--config secrets.json] [--env secrets.env] [--auth-profiles auth.json] [--check] [--dry-run]"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Colors ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}✅ $1${NC}"; }
warn() { echo -e "  ${YELLOW}⚠️  $1${NC}"; }
fail() { echo -e "  ${RED}❌ $1${NC}"; }

# ── Check mode ────────────────────────────────────────────────────────────────
if [ "$CHECK_ONLY" = true ]; then
  echo ">>> Checking OpenClaw installation..."
  errors=0

  if command -v openclaw &>/dev/null; then
    ok "openclaw CLI found: $(which openclaw)"
  else
    fail "openclaw CLI not found"; ((errors++))
  fi

  if [ -f "$OPENCLAW_DIR/openclaw.json" ]; then
    ok "Config file exists: $OPENCLAW_DIR/openclaw.json"
    # Check for required keys
    if command -v jq &>/dev/null; then
      for key in channels gateway agents; do
        if jq -e ".$key" "$OPENCLAW_DIR/openclaw.json" &>/dev/null; then
          ok "  Config has .$key"
        else
          warn "  Config missing .$key"
        fi
      done
    fi
  else
    fail "Config file missing: $OPENCLAW_DIR/openclaw.json"; ((errors++))
  fi

  if [ -f "$OPENCLAW_DIR/.env" ]; then
    ok "Env file exists: $OPENCLAW_DIR/.env"
    # Check for common keys
    for var in ANTHROPIC_API_KEY OPENAI_API_KEY; do
      if grep -q "^${var}=.\+" "$OPENCLAW_DIR/.env" 2>/dev/null; then
        ok "  $var is set"
      else
        warn "  $var is empty or missing"
      fi
    done
  else
    fail "Env file missing: $OPENCLAW_DIR/.env"; ((errors++))
  fi

  AUTH_PROFILES_PATH="$OPENCLAW_DIR/agents/main/agent/auth-profiles.json"
  if [ -f "$AUTH_PROFILES_PATH" ]; then
    ok "Auth profiles exist: $AUTH_PROFILES_PATH"
    if command -v jq &>/dev/null; then
      profile_count=$(jq -r '.profiles | keys | length' "$AUTH_PROFILES_PATH" 2>/dev/null || echo 0)
      ok "  $profile_count auth profile(s) configured"
    fi
  else
    warn "Auth profiles missing: $AUTH_PROFILES_PATH"
  fi

  if openclaw gateway status &>/dev/null; then
    ok "Gateway is running"
  else
    warn "Gateway is not running"
  fi

  if [ "$errors" -gt 0 ]; then
    echo ""
    fail "$errors issue(s) found"
    exit 1
  else
    echo ""
    ok "OpenClaw installation looks good!"
    exit 0
  fi
fi

# ── Validate inputs ──────────────────────────────────────────────────────────
if [ -z "$CONFIG_FILE" ]; then
  echo "Error: --config is required (your filled-in openclaw-secrets.json)"
  echo ""
  echo "Quick start:"
  echo "  1. cp config/openclaw-config.template.json openclaw-secrets.json"
  echo "  2. cp config/openclaw-env.template openclaw-secrets.env"
  echo "  3. Fill in your API keys and tokens"
  echo "  4. $0 --config openclaw-secrets.json --env openclaw-secrets.env"
  exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
  fail "Config file not found: $CONFIG_FILE"
  exit 1
fi

if [ -n "$ENV_FILE" ] && [ ! -f "$ENV_FILE" ]; then
  fail "Env file not found: $ENV_FILE"
  exit 1
fi

if [ -n "$AUTH_PROFILES_FILE" ] && [ ! -f "$AUTH_PROFILES_FILE" ]; then
  fail "Auth profiles file not found: $AUTH_PROFILES_FILE"
  exit 1
fi

# Validate JSON
if ! python3 -c "import json; json.load(open('$CONFIG_FILE'))" 2>/dev/null; then
  fail "Invalid JSON in $CONFIG_FILE"
  exit 1
fi

if [ -n "$AUTH_PROFILES_FILE" ]; then
  if ! python3 -c "import json; json.load(open('$AUTH_PROFILES_FILE'))" 2>/dev/null; then
    fail "Invalid JSON in $AUTH_PROFILES_FILE"
    exit 1
  fi
fi

# ── Dry run ───────────────────────────────────────────────────────────────────
if [ "$DRY_RUN" = true ]; then
  echo ">>> Dry run — would perform:"
  echo "  mkdir -p $OPENCLAW_DIR"
  echo "  cp $CONFIG_FILE → $OPENCLAW_DIR/openclaw.json"
  [ -n "$ENV_FILE" ] && echo "  cp $ENV_FILE → $OPENCLAW_DIR/.env"
  [ -n "$AUTH_PROFILES_FILE" ] && echo "  cp $AUTH_PROFILES_FILE → $OPENCLAW_DIR/agents/main/agent/auth-profiles.json"
  echo "  openclaw gateway install (launchd daemon)"
  echo "  openclaw gateway start"
  exit 0
fi

# ── Install ───────────────────────────────────────────────────────────────────
echo ">>> Setting up OpenClaw..."

# 1. Create directory
mkdir -p "$OPENCLAW_DIR"
ok "Directory: $OPENCLAW_DIR"

# 2. Place config file
if [ -f "$OPENCLAW_DIR/openclaw.json" ]; then
  # Merge: keep existing config, overlay with new values
  if command -v jq &>/dev/null; then
    echo "  Merging config with existing $OPENCLAW_DIR/openclaw.json..."
    MERGED=$(jq -s '.[0] * .[1]' "$OPENCLAW_DIR/openclaw.json" "$CONFIG_FILE")
    echo "$MERGED" > "$OPENCLAW_DIR/openclaw.json"
    ok "Config merged (existing values preserved, new values added)"
  else
    cp "$CONFIG_FILE" "$OPENCLAW_DIR/openclaw.json"
    ok "Config replaced (install jq for merge behavior)"
  fi
else
  cp "$CONFIG_FILE" "$OPENCLAW_DIR/openclaw.json"
  ok "Config installed: $OPENCLAW_DIR/openclaw.json"
fi

# 2b. Strip empty-string sensitive values to prevent RangeError crash
# OpenClaw's redactRawText() calls replaceAll("") on empty values, which
# explodes the config string exponentially and crashes the gateway.
if command -v jq &>/dev/null && [ -f "$OPENCLAW_DIR/openclaw.json" ]; then
  CLEANED=$(jq '
    # Remove empty string env vars
    (if .env.vars then .env.vars |= with_entries(select(.value != "")) else . end) |
    # Remove empty string channel tokens
    (if .channels.discord.token == "" then del(.channels.discord.token) else . end) |
    (if .channels.telegram.botToken == "" then del(.channels.telegram.botToken) else . end) |
    (if .channels.slack.botToken == "" then del(.channels.slack.botToken) else . end) |
    (if .channels.slack.appToken == "" then del(.channels.slack.appToken) else . end) |
    # Remove empty string gateway token
    (if .gateway.auth.token == "" then del(.gateway.auth.token) else . end) |
    # Remove empty string skill API keys
    (if .skills.entries then .skills.entries |= with_entries(
      .value |= with_entries(select(.value != ""))
    ) | .skills.entries |= with_entries(select(.value | length > 0)) else . end)
  ' "$OPENCLAW_DIR/openclaw.json" 2>/dev/null) || CLEANED=""
  if [ -n "$CLEANED" ]; then
    echo "$CLEANED" > "$OPENCLAW_DIR/openclaw.json"
    ok "Stripped empty sensitive values (prevents RangeError crash)"
  fi
fi

# 3. Place env file
if [ -n "$ENV_FILE" ]; then
  if [ -f "$OPENCLAW_DIR/.env" ]; then
    # Merge: add new vars, don't overwrite existing non-empty values
    echo "  Merging env with existing $OPENCLAW_DIR/.env..."
    while IFS= read -r line; do
      # Skip comments and empty lines
      [[ "$line" =~ ^[[:space:]]*# ]] && continue
      [[ -z "$line" ]] && continue

      var_name="${line%%=*}"
      var_value="${line#*=}"

      # Only add if not already set with a value
      if grep -q "^${var_name}=.\+" "$OPENCLAW_DIR/.env" 2>/dev/null; then
        : # Already set, skip
      elif grep -q "^${var_name}=" "$OPENCLAW_DIR/.env" 2>/dev/null; then
        # Exists but empty — update it
        if [ -n "$var_value" ]; then
          sed -i '' "s|^${var_name}=.*|${var_name}=${var_value}|" "$OPENCLAW_DIR/.env"
        fi
      else
        # Doesn't exist — append
        echo "$line" >> "$OPENCLAW_DIR/.env"
      fi
    done < "$ENV_FILE"
    ok "Env merged (existing values preserved)"
  else
    cp "$ENV_FILE" "$OPENCLAW_DIR/.env"
    ok "Env installed: $OPENCLAW_DIR/.env"
  fi
  chmod 600 "$OPENCLAW_DIR/.env"
fi

# 3b. Place auth profiles
if [ -n "$AUTH_PROFILES_FILE" ]; then
  AUTH_PROFILES_DIR="$OPENCLAW_DIR/agents/main/agent"
  mkdir -p "$AUTH_PROFILES_DIR"
  AUTH_PROFILES_PATH="$AUTH_PROFILES_DIR/auth-profiles.json"

  if [ -f "$AUTH_PROFILES_PATH" ]; then
    if command -v jq &>/dev/null; then
      echo "  Merging auth profiles with existing..."
      # Deep merge: existing profiles preserved, new ones added
      MERGED=$(jq -s '.[0] * .[1] | .profiles = (.[0].profiles // {} ) * (.[1].profiles // {})' \
        "$AUTH_PROFILES_PATH" "$AUTH_PROFILES_FILE" 2>/dev/null) || MERGED=""
      if [ -n "$MERGED" ]; then
        echo "$MERGED" > "$AUTH_PROFILES_PATH"
        ok "Auth profiles merged"
      else
        cp "$AUTH_PROFILES_FILE" "$AUTH_PROFILES_PATH"
        ok "Auth profiles replaced (merge failed)"
      fi
    else
      cp "$AUTH_PROFILES_FILE" "$AUTH_PROFILES_PATH"
      ok "Auth profiles replaced"
    fi
  else
    cp "$AUTH_PROFILES_FILE" "$AUTH_PROFILES_PATH"
    ok "Auth profiles installed: $AUTH_PROFILES_PATH"
  fi
  chmod 600 "$AUTH_PROFILES_PATH"
fi

# 4. Generate gateway token if not set
if [ -f "$OPENCLAW_DIR/.env" ]; then
  if ! grep -q "^OPENCLAW_GATEWAY_TOKEN=.\+" "$OPENCLAW_DIR/.env" 2>/dev/null; then
    TOKEN=$(openssl rand -hex 24)
    if grep -q "^OPENCLAW_GATEWAY_TOKEN=" "$OPENCLAW_DIR/.env"; then
      sed -i '' "s|^OPENCLAW_GATEWAY_TOKEN=.*|OPENCLAW_GATEWAY_TOKEN=$TOKEN|" "$OPENCLAW_DIR/.env"
    else
      echo "OPENCLAW_GATEWAY_TOKEN=$TOKEN" >> "$OPENCLAW_DIR/.env"
    fi
    ok "Generated gateway token"

    # Also update the JSON config
    if command -v jq &>/dev/null; then
      TMP=$(jq --arg t "$TOKEN" '.gateway.auth.token = $t' "$OPENCLAW_DIR/openclaw.json")
      echo "$TMP" > "$OPENCLAW_DIR/openclaw.json"
    fi
  fi
fi

# 5. Install and start the daemon
echo ">>> Installing OpenClaw daemon..."
if command -v openclaw &>/dev/null; then
  if openclaw gateway status &>/dev/null 2>&1; then
    warn "Gateway already running — restarting to pick up new config..."
    openclaw gateway restart 2>&1 || true
    ok "Gateway restarted"
  else
    # Install launchd service
    openclaw gateway install 2>&1 || true
    openclaw gateway start 2>&1 || true
    ok "Gateway installed and started"
  fi
else
  fail "openclaw CLI not found — install it first (bun install -g openclaw)"
  exit 1
fi

# 6. Create workspace directory
WORKSPACE="$OPENCLAW_DIR/workspace"
mkdir -p "$WORKSPACE"
ok "Workspace: $WORKSPACE"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  OpenClaw setup complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Config: $OPENCLAW_DIR/openclaw.json"
[ -n "$ENV_FILE" ] && echo "  Env:    $OPENCLAW_DIR/.env"
echo ""
echo "  Check status:  openclaw gateway status"
echo "  View logs:     openclaw gateway logs"
echo "  Verify setup:  $0 --check"
echo ""

# Check which channels are enabled
if command -v jq &>/dev/null; then
  echo "  Enabled channels:"
  for ch in discord telegram slack; do
    if jq -e ".channels.$ch.enabled == true" "$OPENCLAW_DIR/openclaw.json" &>/dev/null; then
      ok "$ch"
    fi
  done
fi
echo ""
