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
  if [ -f "$ENV_FILE" ]; then
    grep "^${key}=" "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2-
  fi
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

# ── 4. Decode config bundle → openclaw.json ──────────────────────────────────

log "Step 4: Config bundle..."

CONFIG_BUNDLE_B64="$(env_get CONFIG_BUNDLE_B64)"

if [ -n "$CONFIG_BUNDLE_B64" ]; then
  mkdir -p "$OPENCLAW_DIR"
  if [ -f "$OPENCLAW_DIR/openclaw.json" ]; then
    # Merge: existing config preserved, bundle overlaid
    BUNDLE_FILE=$(mktemp)
    echo "$CONFIG_BUNDLE_B64" | base64 -d > "$BUNDLE_FILE"
    MERGED=$(jq -s '.[0] * .[1]' "$OPENCLAW_DIR/openclaw.json" "$BUNDLE_FILE")
    echo "$MERGED" > "$OPENCLAW_DIR/openclaw.json"
    rm -f "$BUNDLE_FILE"
    log "Config bundle merged into existing openclaw.json."
  else
    echo "$CONFIG_BUNDLE_B64" | base64 -d > "$OPENCLAW_DIR/openclaw.json"
    log "Config bundle decoded to openclaw.json."
  fi
else
  log "No CONFIG_BUNDLE_B64 in .env — skipping config bundle."
fi

# ── 5. Run bootstrap-openclaw-workspace.sh ───────────────────────────────────

log "Step 5: Bootstrapping workspace..."

BOOTSTRAP="$REPO_DIR/shared/scripts/bootstrap-openclaw-workspace.sh"

if [ -x "$BOOTSTRAP" ] || [ -f "$BOOTSTRAP" ]; then
  bash "$BOOTSTRAP" --skip-cron --skip-skills
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
      skill="$(echo "$skill" | xargs)"  # trim whitespace
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
