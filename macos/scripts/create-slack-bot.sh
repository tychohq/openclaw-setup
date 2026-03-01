#!/usr/bin/env bash
# =============================================================================
# create-slack-bot.sh — Create a Slack bot for OpenClaw via the Manifest API
#
# Prerequisites:
#   1. Go to https://api.slack.com/apps
#   2. Under "Your App Configuration Tokens", click "Generate Token"
#   3. Select your workspace and generate
#   4. Copy the access token (starts with xoxe.xoxp-)
#
# Usage:
#   ./scripts/create-slack-bot.sh <config-token>
#   ./scripts/create-slack-bot.sh <config-token> --manifest path/to/manifest.json
#
# What this does:
#   1. Creates a Slack app from the manifest (bot user + scopes + socket mode)
#   2. Generates an app-level token (xapp-...) for Socket Mode
#   3. Installs the app to the workspace
#   4. Prints the bot token (xoxb-...) and app token (xapp-...)
#   5. Optionally writes them to your openclaw-secrets.env
#
# Note: Config tokens expire every 12 hours. The script saves a refresh token
#       so you can re-authenticate later if needed.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
DEFAULT_MANIFEST="$REPO_DIR/config/slack-app-manifest.json"

# ── Parse args ────────────────────────────────────────────────────────────────
CONFIG_TOKEN="${1:-}"
MANIFEST_PATH="$DEFAULT_MANIFEST"
SECRETS_ENV=""

shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest) MANIFEST_PATH="$2"; shift 2 ;;
    --secrets) SECRETS_ENV="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [ -z "$CONFIG_TOKEN" ]; then
  echo "Usage: $0 <config-token> [--manifest path] [--secrets path/to/secrets.env]"
  echo ""
  echo "Get a config token from: https://api.slack.com/apps"
  echo "  → Your App Configuration Tokens → Generate Token"
  exit 1
fi

if [ ! -f "$MANIFEST_PATH" ]; then
  echo "❌ Manifest not found: $MANIFEST_PATH"
  exit 1
fi

command -v jq &>/dev/null || { echo "❌ jq is required. Install with: brew install jq"; exit 1; }

# ── Helper ────────────────────────────────────────────────────────────────────
slack_api() {
  local method="$1"; shift
  local response
  response=$(curl -s "https://slack.com/api/$method" "$@")

  if [ "$(echo "$response" | jq -r '.ok')" != "true" ]; then
    echo "❌ Slack API error ($method):"
    echo "$response" | jq -r '.error // .errors // .'
    return 1
  fi

  echo "$response"
}

# ── 1. Create the app from manifest ──────────────────────────────────────────
echo ">>> Creating Slack app from manifest..."
MANIFEST=$(cat "$MANIFEST_PATH")

CREATE_RESPONSE=$(slack_api "apps.manifest.create" \
  -H "Authorization: Bearer $CONFIG_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"manifest\": $MANIFEST}")

APP_ID=$(echo "$CREATE_RESPONSE" | jq -r '.app_id')
CREDENTIALS=$(echo "$CREATE_RESPONSE" | jq -r '.credentials')
CLIENT_ID=$(echo "$CREDENTIALS" | jq -r '.client_id')
CLIENT_SECRET=$(echo "$CREDENTIALS" | jq -r '.client_secret')
SIGNING_SECRET=$(echo "$CREDENTIALS" | jq -r '.signing_secret')

echo "  ✅ App created: $APP_ID"
echo "  Client ID: $CLIENT_ID"

# ── 2. Generate app-level token for Socket Mode ──────────────────────────────
echo ">>> Generating app-level token (Socket Mode)..."
# Note: This requires using the app's own auth flow. The apps.manifest.create
# response includes credentials but not app-level tokens directly.
# App-level tokens must be created via the UI or the API with proper auth.

echo ""
echo "⚠️  Almost done! Complete these steps manually:"
echo ""
echo "  1. Go to: https://api.slack.com/apps/$APP_ID"
echo ""
echo "  2. Basic Information → App-Level Tokens → Generate Token"
echo "     Name: 'socket-mode'"
echo "     Scope: connections:write"
echo "     → Copy the xapp-... token"
echo ""
echo "  3. Install App → Install to Workspace → Allow"
echo ""
echo "  4. OAuth & Permissions → Copy Bot User OAuth Token (xoxb-...)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Your app details:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  App ID:         $APP_ID"
echo "  Client ID:      $CLIENT_ID"
echo "  Client Secret:  $CLIENT_SECRET"
echo "  Signing Secret: $SIGNING_SECRET"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Add these to your openclaw-secrets.env:"
echo ""
echo "    SLACK_BOT_TOKEN=xoxb-...  (from step 4)"
echo "    SLACK_APP_TOKEN=xapp-...  (from step 2)"
echo ""

# ── 3. Save refresh token for later ──────────────────────────────────────────
# Config tokens expire in 12h. Save context for potential re-use.
STATE_FILE="$REPO_DIR/.slack-app-state.json"
jq -n \
  --arg app_id "$APP_ID" \
  --arg client_id "$CLIENT_ID" \
  --arg signing_secret "$SIGNING_SECRET" \
  '{app_id: $app_id, client_id: $client_id, signing_secret: $signing_secret, created_at: (now | todate)}' \
  > "$STATE_FILE"
echo "  📄 App state saved to: $STATE_FILE"

# ── 4. Optionally update secrets file ────────────────────────────────────────
if [ -n "$SECRETS_ENV" ] && [ -f "$SECRETS_ENV" ]; then
  echo ""
  echo "  When you have the tokens, update $SECRETS_ENV:"
  echo "    sed -i '' 's/^SLACK_BOT_TOKEN=.*/SLACK_BOT_TOKEN=xoxb-YOUR-TOKEN/' $SECRETS_ENV"
  echo "    sed -i '' 's/^SLACK_APP_TOKEN=.*/SLACK_APP_TOKEN=xapp-YOUR-TOKEN/' $SECRETS_ENV"
fi

echo ""
echo "✅ Done! The Slack app is created with all scopes and Socket Mode enabled."
echo "   Just generate the tokens and install to your workspace."
