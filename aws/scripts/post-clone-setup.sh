#!/usr/bin/env bash
# =============================================================================
# post-clone-setup.sh — Runs as ec2-user after openclaw-setup repo is cloned.
#
# Configures GOG CLI, decodes bundled config/credentials from .env, bootstraps
# the workspace, installs skills, sets up cron jobs, deploys first-boot skill,
# and starts the gateway.
#
# Idempotent — safe to re-run.
#
# Usage:
#   bash ~/openclaw-setup/aws/scripts/post-clone-setup.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
OPENCLAW_DIR="$HOME/.openclaw"
ENV_FILE="$OPENCLAW_DIR/.env"

log() { echo "[$(date)] $1"; }

# ── Helper: read a var from .env ─────────────────────────────────────────────

env_get() {
  local key="$1"
  local val=""
  if [ -f "$ENV_FILE" ]; then
    val="$(grep "^${key}=" "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2- || true)"
  fi
  # Strip optional surrounding double quotes
  val="${val%\"}"
  val="${val#\"}"
  echo "$val"
}

# ── 1. Install GOG CLI (Linux ARM64) ────────────────────────────────────────

log "Step 1: Installing GOG CLI..."

if command -v gog &>/dev/null; then
  log "GOG CLI already installed: $(gog --version 2>/dev/null || echo 'unknown')"
else
  GOG_VERSION=$(curl -fsSL https://api.github.com/repos/steipete/gogcli/releases/latest | jq -r '.tag_name' | sed 's/^v//')
  GOG_TARBALL="gogcli_${GOG_VERSION}_linux_arm64.tar.gz"
  GOG_URL="https://github.com/steipete/gogcli/releases/download/v${GOG_VERSION}/${GOG_TARBALL}"

  TMP_DIR=$(mktemp -d)
  curl -fsSL "$GOG_URL" -o "$TMP_DIR/$GOG_TARBALL"
  tar -xzf "$TMP_DIR/$GOG_TARBALL" -C "$TMP_DIR"
  sudo install -m 755 "$TMP_DIR/gog" /usr/local/bin/gog
  rm -rf "$TMP_DIR"

  log "GOG CLI installed: $(gog --version 2>/dev/null || echo "$GOG_VERSION")"
fi

# ── 2. Configure GOG file keyring + generate password ───────────────────────

log "Step 2: Configuring GOG keyring..."

GOG_KEYRING_PASSWORD="$(env_get GOG_KEYRING_PASSWORD)"

if [ -z "$GOG_KEYRING_PASSWORD" ]; then
  GOG_KEYRING_PASSWORD="$(openssl rand -hex 24)"
  if grep -q "^GOG_KEYRING_PASSWORD=" "$ENV_FILE" 2>/dev/null; then
    sed -i "s|^GOG_KEYRING_PASSWORD=.*|GOG_KEYRING_PASSWORD=${GOG_KEYRING_PASSWORD}|" "$ENV_FILE"
  else
    echo "GOG_KEYRING_PASSWORD=${GOG_KEYRING_PASSWORD}" >> "$ENV_FILE"
  fi
  log "Generated GOG keyring password and saved to .env"
else
  log "GOG keyring password already set in .env"
fi

export GOG_KEYRING_PASSWORD
gog auth keyring file
log "GOG file keyring configured."

# ── 3. Set Google OAuth credentials ─────────────────────────────────────────

log "Step 3: Google OAuth credentials..."

GOOGLE_OAUTH_CREDENTIALS_B64="$(env_get GOOGLE_OAUTH_CREDENTIALS_B64)"

if [ -n "$GOOGLE_OAUTH_CREDENTIALS_B64" ]; then
  CREDS_FILE=$(mktemp)
  echo "$GOOGLE_OAUTH_CREDENTIALS_B64" | base64 -d > "$CREDS_FILE"
  gog auth credentials set "$CREDS_FILE"
  rm -f "$CREDS_FILE"
  log "Google OAuth credentials set via GOG CLI."
else
  log "No GOOGLE_OAUTH_CREDENTIALS_B64 in .env — skipping Google credentials."
fi

# ── 4. Base config + config bundle (handled in step 4b below) ────────────────

log "Step 4: Config generation deferred to step 4b..."

# ── 4b. Generate base openclaw.json from .env vars ───────────────────────────

log "Step 4b: Generating base openclaw.json from .env..."

OPENCLAW_JSON="$OPENCLAW_DIR/openclaw.json"

# If no config exists yet, generate from .env
if [ ! -f "$OPENCLAW_JSON" ] || [ "$(cat "$OPENCLAW_JSON")" = "{}" ]; then
    GATEWAY_AUTH_TOKEN="$(env_get GATEWAY_AUTH_TOKEN)"
    OWNER_NAME="$(env_get OWNER_NAME)"
    ASSISTANT_NAME="$(env_get ASSISTANT_NAME)"

    # Start with base gateway config
    CONFIG=$(jq -n \
      --arg token "${GATEWAY_AUTH_TOKEN:-}" \
      '{
        gateway: {
          mode: "local",
          auth: { token: $token },
          port: 18789
        }
      }')

    # Add Slack channel if configured
    SLACK_BOT_TOKEN="$(env_get SLACK_BOT_TOKEN)"
    SLACK_APP_TOKEN="$(env_get SLACK_APP_TOKEN)"
    SLACK_OWNER_USER_ID="$(env_get SLACK_OWNER_USER_ID)"
    if [ -n "$SLACK_BOT_TOKEN" ]; then
        CONFIG=$(echo "$CONFIG" | jq \
          --arg app_token "${SLACK_APP_TOKEN:-}" \
          --arg bot_token "$SLACK_BOT_TOKEN" \
          --arg owner_id "${SLACK_OWNER_USER_ID:-}" \
          '.channels.slack = {
            enabled: true,
            mode: "socket",
            appToken: $app_token,
            botToken: $bot_token,
            dmPolicy: "allowlist",
            allowFrom: (if $owner_id != "" then [$owner_id] else [] end)
          }')
    fi

    # Add Discord channel if configured
    DISCORD_TOKEN="$(env_get DISCORD_TOKEN)"
    [ -z "$DISCORD_TOKEN" ] && DISCORD_TOKEN="$(env_get DISCORD_BOT_TOKEN)"
    DISCORD_GUILD_ID="$(env_get DISCORD_GUILD_ID)"
    DISCORD_OWNER_ID="$(env_get DISCORD_OWNER_ID)"
    if [ -n "$DISCORD_TOKEN" ]; then
        CONFIG=$(echo "$CONFIG" | jq \
          --arg token "$DISCORD_TOKEN" \
          --arg guild_id "${DISCORD_GUILD_ID:-}" \
          --arg owner_id "${DISCORD_OWNER_ID:-}" \
          '.channels.discord = {
            enabled: true,
            botToken: $token,
            guildId: $guild_id,
            dmPolicy: "allowlist",
            allowFrom: (if $owner_id != "" then [$owner_id] else [] end)
          }')
    fi

    # Add Telegram channel if configured
    TELEGRAM_BOT_TOKEN="$(env_get TELEGRAM_BOT_TOKEN)"
    TELEGRAM_OWNER_ID="$(env_get TELEGRAM_OWNER_ID)"
    if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
        CONFIG=$(echo "$CONFIG" | jq \
          --arg token "$TELEGRAM_BOT_TOKEN" \
          --arg owner_id "${TELEGRAM_OWNER_ID:-}" \
          '.channels.telegram = {
            enabled: true,
            botToken: $token,
            dmPolicy: "allowlist",
            allowFrom: (if ($owner_id|test("^[0-9]+$")) then [($owner_id|tonumber)] else [] end)
          }')
    fi

    # Add Bedrock bearer token to env if configured
    AWS_BEARER_TOKEN_BEDROCK="$(env_get AWS_BEARER_TOKEN_BEDROCK)"
    if [ -n "$AWS_BEARER_TOKEN_BEDROCK" ]; then
        CONFIG=$(echo "$CONFIG" | jq --arg token "$AWS_BEARER_TOKEN_BEDROCK" '.env.vars.AWS_BEARER_TOKEN_BEDROCK = $token')
    fi

    # Add GOG keyring password so agent can run gog commands
    GOG_KP="$(env_get GOG_KEYRING_PASSWORD)"
    if [ -n "$GOG_KP" ]; then
        CONFIG=$(echo "$CONFIG" | jq --arg pw "$GOG_KP" '.env.vars.GOG_KEYRING_PASSWORD = $pw')
    fi

    # Set default model based on available API keys
    # Bedrock first (cheaper), then direct Anthropic, then OpenAI
    ANTHROPIC_API_KEY="$(env_get ANTHROPIC_API_KEY)"
    OPENAI_API_KEY="$(env_get OPENAI_API_KEY)"
    DEFAULT_MODEL=""
    if [ -n "$AWS_BEARER_TOKEN_BEDROCK" ]; then
        # Bedrock requires inference profile IDs (us. prefix), not bare model IDs.
        # AWS_REGION from .env drives the API endpoint URL.
        # Model ID uses the US cross-region inference profile (works in all US regions).
        BEDROCK_REGION="$(env_get AWS_REGION)"
        BEDROCK_REGION="${BEDROCK_REGION:-us-east-1}"
        BEDROCK_MODEL_ID="us.anthropic.claude-opus-4-6-v1"
        DEFAULT_MODEL="amazon-bedrock/${BEDROCK_MODEL_ID}"

        CONFIG=$(echo "$CONFIG" | jq           --arg region "$BEDROCK_REGION"           --arg model_id "$BEDROCK_MODEL_ID"           '.models.providers["amazon-bedrock"] = {
            baseUrl: ("https://bedrock-runtime." + $region + ".amazonaws.com"),
            api: "bedrock-converse-stream",
            auth: "aws-sdk",
            models: [{ id: $model_id, name: "Claude Opus 4.6" }]
          }')
    elif [ -n "$ANTHROPIC_API_KEY" ]; then
        DEFAULT_MODEL="anthropic/claude-opus-4-6"
    elif [ -n "$OPENAI_API_KEY" ]; then
        DEFAULT_MODEL="openai/gpt-4.1"
    fi
    if [ -n "$DEFAULT_MODEL" ]; then
        CONFIG=$(echo "$CONFIG" | jq --arg m "$DEFAULT_MODEL" '.agents.defaults.model = $m')
    fi

    # Always add custom skills directory so ~/.openclaw/skills/ is discoverable
    CONFIG=$(echo "$CONFIG" | jq '.skills.load.extraDirs = ["~/.openclaw/skills"]')

    echo "$CONFIG" | jq . > "$OPENCLAW_JSON"
    log "Generated openclaw.json with gateway + channel config."
else
    log "openclaw.json already exists — skipping base config generation."
fi

# Now merge config bundle on top (if present)
CONFIG_BUNDLE_B64_VAL="$(env_get CONFIG_BUNDLE_B64)"
if [ -n "$CONFIG_BUNDLE_B64_VAL" ]; then
    BUNDLE_FILE=$(mktemp)
    echo "$CONFIG_BUNDLE_B64_VAL" | base64 -d | gunzip > "$BUNDLE_FILE"

    # Apply config patches: extract all config values from bundle and deep-merge into openclaw.json
    # Uses a single jq call to avoid shell quoting issues
    MERGED=$(jq -s '
      .[0] as $bundle | .[1] as $base |
      [$bundle.patches[]?.steps[]? | select(.type == "config_patch") | .merge_file] |
      unique |
      reduce .[] as $f ($base; . * ($bundle.configs[$f] // {}))
    ' "$BUNDLE_FILE" "$OPENCLAW_JSON")

    if [ -n "$MERGED" ] && [ "$MERGED" != "null" ]; then
        echo "$MERGED" > "$OPENCLAW_JSON"
        PATCH_NAMES=$(jq -r '[.patches[].id] | join(", ")' "$BUNDLE_FILE")
        log "Applied config patches: $PATCH_NAMES"
    fi

    # Handle bundled skills allowlist
    BUNDLED_SKILLS=$(jq -r '.manifest.selectedBundledSkills // [] | .[]' "$BUNDLE_FILE" 2>/dev/null)
    if [ -n "$BUNDLED_SKILLS" ]; then
        SKILLS_JSON=$(echo "$BUNDLED_SKILLS" | jq -R . | jq -s .)
        CURRENT=$(cat "$OPENCLAW_JSON")
        echo "$CURRENT" | jq --argjson skills "$SKILLS_JSON" '.skills.allowBundled = $skills' > "$OPENCLAW_JSON"
        log "Set bundled skills allowlist: $(echo "$BUNDLED_SKILLS" | tr '\n' ', ')"
    fi

    rm -f "$BUNDLE_FILE"
fi

# ── 5. Run bootstrap-openclaw-workspace.sh ───────────────────────────────────

log "Step 5: Bootstrapping workspace..."

BOOTSTRAP="$REPO_DIR/shared/scripts/bootstrap-openclaw-workspace.sh"

if [ -x "$BOOTSTRAP" ] || [ -f "$BOOTSTRAP" ]; then
  bash "$BOOTSTRAP" --skip-cron --skip-skills

  # Overwrite with cloud-specific versions
  CLOUD_WS="$REPO_DIR/aws/workspace"
  if [ -d "$CLOUD_WS" ]; then
    # Replace AGENTS.md with first-boot version (onboarding flow)
    [ -f "$CLOUD_WS/AGENTS.md" ] && cp -f "$CLOUD_WS/AGENTS.md" "$OPENCLAW_DIR/workspace/AGENTS.md"

    # Put the real AGENTS.md in bootstrap/ so first-boot can swap it in when done
    [ -f "$CLOUD_WS/AGENTS-real.md" ] && cp -f "$CLOUD_WS/AGENTS-real.md" "$OPENCLAW_DIR/workspace/bootstrap/AGENTS-real.md"

    # Replace bootstrap files with cloud versions
    [ -d "$CLOUD_WS/bootstrap" ] && cp -f "$CLOUD_WS/bootstrap/"* "$OPENCLAW_DIR/workspace/bootstrap/"

    log "Applied cloud workspace overlay (first-boot AGENTS.md + cloud bootstrap)."
  fi

  log "Workspace bootstrap complete."
else
  log "WARNING: bootstrap-openclaw-workspace.sh not found at $BOOTSTRAP"
fi

# ── 6. Install ClawHub skills ────────────────────────────────────────────────

log "Step 6: Installing ClawHub skills..."

CLAWHUB_SKILLS="$(env_get CLAWHUB_SKILLS)"

if [ -n "$CLAWHUB_SKILLS" ]; then
  if command -v clawhub &>/dev/null; then
    IFS=',' read -ra SKILLS <<< "$CLAWHUB_SKILLS"
    for skill in "${SKILLS[@]}"; do
      skill="${skill## }"
      skill="${skill%% }"
      [ -z "$skill" ] && continue
      if [ -d "$HOME/.agents/skills/$skill" ]; then
        log "  Skill $skill already installed — skipping."
      else
        clawhub install "$skill" 2>&1 || log "  WARNING: Failed to install skill: $skill"
      fi
    done
    log "ClawHub skill installation complete."
  else
    log "WARNING: clawhub not found — cannot install skills."
  fi
else
  log "No CLAWHUB_SKILLS in .env — skipping skill installation."
fi

# ── 7. Decode and write cron job files ───────────────────────────────────────

log "Step 7: Cron jobs..."

CRON_SELECTIONS_B64="$(env_get CRON_SELECTIONS_B64)"

if [ -n "$CRON_SELECTIONS_B64" ]; then
  CRON_DIR="$OPENCLAW_DIR/workspace/cron-jobs"
  mkdir -p "$CRON_DIR"

  CRON_JSON=$(echo "$CRON_SELECTIONS_B64" | base64 -d)
  CRON_COUNT=$(echo "$CRON_JSON" | jq 'length')

  for i in $(seq 0 $((CRON_COUNT - 1))); do
    JOB=$(echo "$CRON_JSON" | jq ".[$i]")
    JOB_NAME=$(echo "$JOB" | jq -r '.name // "cron-job-'"$i"'"')
    JOB_FILE="$CRON_DIR/${JOB_NAME}.json"
    if [ -f "$JOB_FILE" ]; then
      log "  Cron job $JOB_NAME already exists — skipping."
    else
      echo "$JOB" > "$JOB_FILE"
      log "  Wrote cron job: $JOB_NAME"
    fi
  done
  log "Cron job setup complete."
else
  log "No CRON_SELECTIONS_B64 in .env — skipping cron jobs."
fi

# ── 8. Deploy first-boot skill + touch flag ──────────────────────────────────

log "Step 8: First-boot skill..."

ENABLE_FIRST_BOOT="$(env_get ENABLE_FIRST_BOOT)"
FIRST_BOOT_SRC="$REPO_DIR/aws/skills/first-boot"
FIRST_BOOT_DEST="$OPENCLAW_DIR/skills/first-boot"

if [ "$ENABLE_FIRST_BOOT" = "true" ] || [ "$ENABLE_FIRST_BOOT" = "1" ]; then
  if [ -d "$FIRST_BOOT_DEST" ] && [ -f "$OPENCLAW_DIR/workspace/.first-boot" ]; then
    log "First-boot skill already deployed — skipping."
  else
    mkdir -p "$OPENCLAW_DIR/skills"
    if [ -d "$FIRST_BOOT_SRC" ]; then
      cp -r "$FIRST_BOOT_SRC" "$FIRST_BOOT_DEST"
      mkdir -p "$OPENCLAW_DIR/workspace"
      touch "$OPENCLAW_DIR/workspace/.first-boot"
      log "First-boot skill deployed and flag set."
    else
      log "WARNING: first-boot skill source not found at $FIRST_BOOT_SRC"
    fi
  fi
else
  log "ENABLE_FIRST_BOOT not set to true — skipping first-boot skill."
fi

# ── 9. Git init ~/.openclaw ──────────────────────────────────────────────────

log "Step 9: Git init ~/.openclaw..."

if [ -d "$OPENCLAW_DIR/.git" ]; then
  log "~/.openclaw is already a git repo — skipping init."
else
  git -C "$OPENCLAW_DIR" init
  git -C "$OPENCLAW_DIR" add -A
  git -C "$OPENCLAW_DIR" commit -m "Initial OpenClaw workspace"
  log "~/.openclaw initialized as git repo with initial commit."
fi

# ── 10. Start gateway ────────────────────────────────────────────────────────

log "Step 10: Starting gateway..."

EC2_UID="$(id -u)"
export XDG_RUNTIME_DIR="/run/user/${EC2_UID}"

if systemctl --user is-active openclaw-gateway &>/dev/null; then
  log "Gateway already running — restarting to pick up config..."
  systemctl --user restart openclaw-gateway
else
  systemctl --user start openclaw-gateway
fi

log "Gateway started."

# ── Done ─────────────────────────────────────────────────────────────────────

log "post-clone-setup.sh complete!"
