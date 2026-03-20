#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# onboard-openclaw.sh — Non-interactive OpenClaw onboarding
#
# Usage:
#   bash onboard-openclaw.sh --token <setup-token>
#   bash onboard-openclaw.sh --token <setup-token> --discord-token <token>
#   bash onboard-openclaw.sh --token <setup-token> --telegram-token <token>
#   bash onboard-openclaw.sh --token <setup-token> --slack-bot-token <token> --slack-app-token <token>
#
# This wraps `openclaw onboard --non-interactive` with the correct defaults:
#   - Anthropic subscription auth (setup-token)
#   - --accept-risk (required for non-interactive)
#   - --install-daemon
#   - --secret-input-mode ref (keys stored as env var references)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

TOKEN=""
DISCORD_TOKEN=""
TELEGRAM_TOKEN=""
SLACK_BOT_TOKEN=""
SLACK_APP_TOKEN=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --token)           shift; TOKEN="$1" ;;
    --discord-token)   shift; DISCORD_TOKEN="$1" ;;
    --telegram-token)  shift; TELEGRAM_TOKEN="$1" ;;
    --slack-bot-token) shift; SLACK_BOT_TOKEN="$1" ;;
    --slack-app-token) shift; SLACK_APP_TOKEN="$1" ;;
    --help|-h)
      echo "Usage: onboard-openclaw.sh --token <setup-token> [channel options]"
      echo ""
      echo "Options:"
      echo "  --token <token>            Claude setup token (required)"
      echo "  --discord-token <token>    Discord bot token"
      echo "  --telegram-token <token>   Telegram bot token"
      echo "  --slack-bot-token <token>  Slack bot token (xoxb-...)"
      echo "  --slack-app-token <token>  Slack app token (xapp-...)"
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
  shift
done

if [ -z "$TOKEN" ]; then
  echo "❌ --token is required. Generate one with: claude setup-token" >&2
  exit 1
fi

if ! command -v openclaw &>/dev/null; then
  echo "❌ openclaw CLI not found. Install it first:" >&2
  echo "   bun install -g openclaw" >&2
  exit 1
fi

# ── Build the onboard command ─────────────────────────────────────────────────

ONBOARD_ARGS=(
  --non-interactive
  --accept-risk
  --install-daemon
  --auth-choice token
  --token "$TOKEN"
  --token-provider anthropic
  --secret-input-mode ref
)

# Skip channels by default, add specific ones if provided
HAS_CHANNEL=false

if [ -n "$DISCORD_TOKEN" ]; then
  HAS_CHANNEL=true
  # Discord token goes into .env; channel config is handled by patches
  echo ">>> Discord token provided — will configure after onboard via patches"
fi

if [ -n "$TELEGRAM_TOKEN" ]; then
  HAS_CHANNEL=true
  echo ">>> Telegram token provided — will configure after onboard via patches"
fi

if [ -n "$SLACK_BOT_TOKEN" ] && [ -n "$SLACK_APP_TOKEN" ]; then
  HAS_CHANNEL=true
  echo ">>> Slack tokens provided — will configure after onboard via patches"
elif [ -n "$SLACK_BOT_TOKEN" ] || [ -n "$SLACK_APP_TOKEN" ]; then
  echo "⚠️  Slack requires both --slack-bot-token and --slack-app-token" >&2
  exit 1
fi

if [ "$HAS_CHANNEL" = false ]; then
  ONBOARD_ARGS+=(--skip-channels)
  echo ">>> No channel tokens provided — skipping channel setup (add later)"
fi

# ── Run onboard ───────────────────────────────────────────────────────────────

echo ""
echo ">>> Running openclaw onboard..."
openclaw onboard "${ONBOARD_ARGS[@]}"

# ── Write channel tokens to .env ──────────────────────────────────────────────

OC_ENV="$HOME/.openclaw/.env"

append_env() {
  local key="$1" val="$2"
  if grep -q "^${key}=" "$OC_ENV" 2>/dev/null; then
    # Update existing
    sed -i '' "s|^${key}=.*|${key}=${val}|" "$OC_ENV"
  else
    echo "${key}=${val}" >> "$OC_ENV"
  fi
  echo "  ✅ ${key} written to ~/.openclaw/.env"
}

if [ -n "$DISCORD_TOKEN" ]; then
  append_env "DISCORD_TOKEN" "$DISCORD_TOKEN"
fi

if [ -n "$TELEGRAM_TOKEN" ]; then
  append_env "TELEGRAM_BOT_TOKEN" "$TELEGRAM_TOKEN"
fi

if [ -n "$SLACK_BOT_TOKEN" ]; then
  append_env "SLACK_BOT_TOKEN" "$SLACK_BOT_TOKEN"
  append_env "SLACK_APP_TOKEN" "$SLACK_APP_TOKEN"
fi

# ── Apply patches ─────────────────────────────────────────────────────────────

PATCH_SCRIPT="$REPO_DIR/shared/patches/scripts/openclaw-patch"
if [ -x "$PATCH_SCRIPT" ]; then
  echo ""
  echo ">>> Applying patches..."
  "$PATCH_SCRIPT" apply || echo "⚠️  Some patches failed — run 'openclaw-patch status' to check"
else
  echo ">>> No patch script found at $PATCH_SCRIPT — skipping patches"
fi

# ── Health check ──────────────────────────────────────────────────────────────

echo ""
echo ">>> Running health check..."
openclaw doctor || echo "⚠️  Health check reported issues — review above"

echo ""
echo "✅ OpenClaw onboarding complete"
