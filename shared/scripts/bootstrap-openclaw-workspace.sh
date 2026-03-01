#!/usr/bin/env bash
# =============================================================================
# bootstrap-openclaw-workspace.sh — Set up OpenClaw workspace, skills, and cron
#
# Copies generic workspace files, installs clawhub skills, and creates
# recommended cron jobs. Run after setup-openclaw.sh.
#
# Usage:
#   ./scripts/bootstrap-openclaw-workspace.sh
#   ./scripts/bootstrap-openclaw-workspace.sh --dry-run
#   ./scripts/bootstrap-openclaw-workspace.sh --skip-cron
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
OPENCLAW_DIR="$HOME/.openclaw"
WORKSPACE="$OPENCLAW_DIR/workspace"

DRY_RUN=false
SKIP_CRON=false
SKIP_SKILLS=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)      DRY_RUN=true; shift ;;
    --skip-cron)    SKIP_CRON=true; shift ;;
    --skip-skills)  SKIP_SKILLS=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--dry-run] [--skip-cron] [--skip-skills]"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'
ok()   { echo -e "  ${GREEN}✅ $1${NC}"; }
skip() { echo -e "  ${YELLOW}⏭️  $1${NC}"; }

run() {
  if [ "$DRY_RUN" = true ]; then
    echo "  [dry-run] $1"
  else
    eval "$2"
    ok "$1"
  fi
}

# ── 1. Create workspace structure ────────────────────────────────────────────

echo ">>> Setting up OpenClaw workspace..."

DIRS=(
  "$WORKSPACE"
  "$WORKSPACE/docs"
  "$WORKSPACE/tools"
  "$WORKSPACE/memory"
  "$WORKSPACE/memory/daily"
  "$WORKSPACE/scripts"
  "$WORKSPACE/templates"
  "$WORKSPACE/images"
  "$WORKSPACE/research"
  "$WORKSPACE/tmp"
  "$WORKSPACE/state"
  "$WORKSPACE/data"
  "$WORKSPACE/config"
  "$WORKSPACE/logs"
)

for dir in "${DIRS[@]}"; do
  if [ -d "$dir" ]; then
    skip "$dir already exists"
  else
    run "mkdir $dir" "mkdir -p '$dir'"
  fi
done

# ── 2. Copy workspace root files ─────────────────────────────────────────────

echo ""
echo ">>> Copying workspace files..."

WORKSPACE_SRC="$REPO_DIR/openclaw-workspace"

if [ ! -d "$WORKSPACE_SRC" ]; then
  skip "No openclaw-workspace/ directory in repo — skipping file copy"
  skip "Create it with your AGENTS.md, SOUL.md, IDENTITY.md, etc."
else
  # Copy root .md files (don't overwrite existing)
  for f in "$WORKSPACE_SRC"/*.md; do
    [ ! -f "$f" ] && continue
    basename="$(basename "$f")"
    dest="$WORKSPACE/$basename"
    if [ -f "$dest" ]; then
      skip "$basename already exists"
    else
      run "copy $basename" "cp '$f' '$dest'"
    fi
  done

  # Copy subdirectories (docs/, tools/, scripts/, templates/, bootstrap/)
  for subdir in docs tools scripts templates bootstrap; do
    if [ -d "$WORKSPACE_SRC/$subdir" ]; then
      for f in "$WORKSPACE_SRC/$subdir"/*; do
        [ ! -f "$f" ] && continue
        basename="$(basename "$f")"
        dest="$WORKSPACE/$subdir/$basename"
        if [ -f "$dest" ]; then
          skip "$subdir/$basename already exists"
        else
          run "copy $subdir/$basename" "cp '$f' '$dest'"
        fi
      done
    fi
  done
fi

# ── 2b. Install pre-commit hook for secret detection ─────────────────────────

echo ""
echo ">>> Setting up git pre-commit hook for secret detection..."

HOOK_SRC="$WORKSPACE/scripts/pre-commit-secrets.sh"
HOOK_DEST="$OPENCLAW_DIR/.git/hooks/pre-commit"

if [ -f "$HOOK_DEST" ]; then
  skip "pre-commit hook already exists"
elif [ ! -d "$OPENCLAW_DIR/.git" ]; then
  skip "~/.openclaw is not a git repo — skipping hook install"
else
  if [ -f "$HOOK_SRC" ]; then
    run "install pre-commit hook" "cp '$HOOK_SRC' '$HOOK_DEST' && chmod +x '$HOOK_DEST'"
  else
    skip "pre-commit-secrets.sh not found in workspace scripts"
  fi
fi

# ── 3. Install clawhub skills ────────────────────────────────────────────────

if [ "$SKIP_SKILLS" = false ]; then
  echo ""
  echo ">>> Installing clawhub skills..."

  CLAWHUB_SKILLS=(
    agent-browser
    architecture-research
    caddy
    commit
    create-mcp
    deslop
    dev-serve
    diagrams
    domain-check
    merge-upstream
    modal
    new-brain-dump
    process-brain-dump
    research
    supabase
    tmux
    ui-scaffold
    vercel
  )

  if command -v clawhub &>/dev/null; then
    for skill in "${CLAWHUB_SKILLS[@]}"; do
      if [ -d "$HOME/.agents/skills/$skill" ]; then
        skip "$skill already installed"
      else
        run "install $skill" "clawhub install '$skill' 2>&1 || true"
      fi
    done
  else
    skip "clawhub not found — install with: bun install -g clawhub"
    echo "     Then run: clawhub install ${CLAWHUB_SKILLS[*]}"
  fi
fi

# ── 4. Copy custom skills ────────────────────────────────────────────────────

echo ""
echo ">>> Checking custom skills..."

CUSTOM_SKILLS_SRC="$REPO_DIR/openclaw-skills"

if [ -d "$CUSTOM_SKILLS_SRC" ]; then
  mkdir -p "$OPENCLAW_DIR/skills"
  for skill_dir in "$CUSTOM_SKILLS_SRC"/*/; do
    [ ! -d "$skill_dir" ] && continue
    skill_name="$(basename "$skill_dir")"
    dest="$OPENCLAW_DIR/skills/$skill_name"
    if [ -d "$dest" ]; then
      skip "skill $skill_name already exists"
    else
      run "copy skill $skill_name" "cp -r '$skill_dir' '$dest'"
    fi
  done
else
  skip "No openclaw-skills/ directory — skipping custom skills"
  skip "Create it with skill subdirectories (each with SKILL.md)"
fi

# ── 5. Create cron jobs ──────────────────────────────────────────────────────

if [ "$SKIP_CRON" = false ]; then
  echo ""
  echo ">>> Setting up cron jobs..."

  if ! command -v openclaw &>/dev/null; then
    skip "openclaw not found — skipping cron setup"
  elif ! openclaw gateway status &>/dev/null 2>&1; then
    skip "gateway not running — start it first, then re-run with cron setup"
  else
    # We'll create cron jobs via the gateway API
    # For now, document the recommended jobs
    echo "  Recommended cron jobs (create via OpenClaw):"
    echo ""
    echo "  • self-reflection       — hourly  (0 * * * *)     — session review + lessons"
    echo "  • system-watchdog       — daily   (0 4 * * *)     — system health check"
    echo "  • cron-health-watchdog  — 6-hourly (0 */6 * * *)  — monitor cron failures"
    echo "  • error-log-digest      — daily   (0 8 * * *)     — gateway error review"
    echo "  • workspace-activity-feed — 6-hourly (0 */6 * * *) — Discord activity posts"
    echo ""
    echo "  Create them by asking OpenClaw: 'Set up the recommended cron jobs'"
    echo "  Or see: config/openclaw-workspace-manifest.md"
  fi
fi

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  OpenClaw workspace bootstrap complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Workspace: $WORKSPACE"
echo ""
echo "  Next:"
echo "  1. Customize workspace files (SOUL.md, USER.md, AGENTS.md)"
echo "  2. Start the gateway: openclaw gateway start"
echo "  3. Ask OpenClaw to create recommended cron jobs"
echo ""
