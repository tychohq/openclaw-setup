#!/usr/bin/env bash
# =============================================================================
# audit-openclaw.sh — Compare an existing OpenClaw install against the template
#
# Usage:
#   ./scripts/audit-openclaw.sh [--workspace-only] [--config-only] [--json]
#
# Pulls down this repo (or uses local clone) and diffs against the running
# OpenClaw installation. Produces a report of:
#   1. Things the template has that you don't (recommended additions)
#   2. Things that conflict (your value vs template value)
#   3. Things you have that might be worth upstreaming to the template
#
# Output: writes audit report to stdout (or JSON with --json)
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Detect OpenClaw workspace
OC_HOME="${OPENCLAW_HOME:-$HOME/.openclaw}"
OC_WORKSPACE="$OC_HOME/workspace"
OC_CONFIG="$OC_HOME/openclaw.json"
OC_SKILLS_CUSTOM="$HOME/.agents/skills"
OC_SKILLS_CLAWHUB="$HOME/.openclaw/skills"

# Template paths
TPL_WORKSPACE="$REPO_DIR/openclaw-workspace"
TPL_SKILLS="$REPO_DIR/openclaw-skills"
TPL_CONFIG="$REPO_DIR/config/openclaw-config.template.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Counters
MISSING=0
CONFLICTS=0
EXTRAS=0

# Parse args
WORKSPACE_ONLY=false
CONFIG_ONLY=false
JSON_OUTPUT=false
for arg in "$@"; do
  case "$arg" in
    --workspace-only) WORKSPACE_ONLY=true ;;
    --config-only) CONFIG_ONLY=true ;;
    --json) JSON_OUTPUT=true ;;
    --help|-h)
      echo "Usage: $0 [--workspace-only] [--config-only] [--json]"
      echo ""
      echo "Compare your OpenClaw install against the mac-mini-setup template."
      echo "  --workspace-only   Only compare workspace files"
      echo "  --config-only      Only compare openclaw.json config"
      echo "  --json             Output as JSON instead of human-readable"
      exit 0
      ;;
  esac
done

# ── Preflight ────────────────────────────────────────────────────────────────

if [ ! -d "$OC_HOME" ]; then
  echo "Error: OpenClaw not found at $OC_HOME"
  exit 1
fi

if [ ! -d "$TPL_WORKSPACE" ]; then
  echo "Error: Template workspace not found at $TPL_WORKSPACE"
  echo "Run this from the mac-mini-setup repo root, or clone it first."
  exit 1
fi

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║       OpenClaw Audit — Template Comparison       ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Template: ${CYAN}$REPO_DIR${NC}"
echo -e "  Install:  ${CYAN}$OC_HOME${NC}"
echo ""

# ── 1. Workspace files ──────────────────────────────────────────────────────

if [ "$CONFIG_ONLY" != true ]; then
  echo -e "${BOLD}━━━ Workspace Files ━━━${NC}"
  echo ""

  # Find all files in template (excluding bootstrap/)
  while IFS= read -r tpl_file; do
    rel_path="${tpl_file#$TPL_WORKSPACE/}"

    # Skip bootstrap folder — that's only for new installs
    [[ "$rel_path" == bootstrap/* ]] && continue

    local_file="$OC_WORKSPACE/$rel_path"

    if [ ! -f "$local_file" ]; then
      echo -e "  ${GREEN}+ MISSING${NC}  $rel_path"
      echo -e "    ${CYAN}→ Template has this file, you don't. Consider adding it.${NC}"
      ((MISSING++))
    else
      # Compare content (ignoring whitespace)
      if ! diff -qbB "$tpl_file" "$local_file" &>/dev/null; then
        echo -e "  ${YELLOW}~ DIFFERS${NC}  $rel_path"
        # Show a brief summary of differences
        diff_lines=$(diff -u "$tpl_file" "$local_file" 2>/dev/null | grep '^[-+]' | grep -v '^[-+][-+][-+]' | wc -l | tr -d ' ')
        echo -e "    ${CYAN}→ $diff_lines lines differ. Your version has local customizations.${NC}"
        ((CONFLICTS++))
      fi
    fi
  done < <(find "$TPL_WORKSPACE" -type f -name "*.md" -o -name "*.sh" | sort)

  # Find files YOU have that the template doesn't
  echo ""
  echo -e "  ${BOLD}Your extras (not in template):${NC}"
  extras_found=false
  while IFS= read -r local_file; do
    rel_path="${local_file#$OC_WORKSPACE/}"

    # Skip generated/personal content
    [[ "$rel_path" == memory/* ]] && continue
    [[ "$rel_path" == research/* ]] && continue
    [[ "$rel_path" == images/* ]] && continue
    [[ "$rel_path" == tmp/* ]] && continue
    [[ "$rel_path" == state/* ]] && continue
    [[ "$rel_path" == logs/* ]] && continue
    [[ "$rel_path" == data/* ]] && continue
    [[ "$rel_path" == diagrams/* ]] && continue
    [[ "$rel_path" == public/* ]] && continue
    [[ "$rel_path" == avatars/* ]] && continue
    [[ "$rel_path" == about-* ]] && continue
    [[ "$rel_path" == recipes/* ]] && continue
    [[ "$rel_path" == bootstrap/* ]] && continue

    tpl_file="$TPL_WORKSPACE/$rel_path"
    if [ ! -f "$tpl_file" ]; then
      echo -e "  ${BLUE}? EXTRA${NC}    $rel_path"
      extras_found=true
      ((EXTRAS++))
    fi
  done < <(find "$OC_WORKSPACE" -type f \( -name "*.md" -o -name "*.sh" \) | sort)

  if [ "$extras_found" = false ]; then
    echo -e "    ${CYAN}(none — your workspace matches the template structure)${NC}"
  fi
  echo ""
fi

# ── 2. Config comparison ────────────────────────────────────────────────────

if [ "$WORKSPACE_ONLY" != true ]; then
  echo -e "${BOLD}━━━ OpenClaw Config (openclaw.json) ━━━${NC}"
  echo ""

  if [ ! -f "$OC_CONFIG" ]; then
    echo -e "  ${RED}✗ No openclaw.json found at $OC_CONFIG${NC}"
  elif [ ! -f "$TPL_CONFIG" ]; then
    echo -e "  ${RED}✗ No template config found at $TPL_CONFIG${NC}"
  else
    # Compare top-level sections
    echo -e "  ${BOLD}Section comparison:${NC}"

    for section in agents models channels plugins memory skills session env auth; do
      tpl_has=$(python3 -c "
import json,sys
with open('$TPL_CONFIG') as f: d=json.load(f)
print('yes' if '$section' in d else 'no')
" 2>/dev/null || echo "error")

      local_has=$(python3 -c "
import json,sys
with open('$OC_CONFIG') as f: d=json.load(f)
print('yes' if '$section' in d else 'no')
" 2>/dev/null || echo "error")

      if [ "$tpl_has" = "yes" ] && [ "$local_has" = "no" ]; then
        echo -e "  ${GREEN}+ MISSING${NC}  $section — template has it, you don't"
        ((MISSING++))
      elif [ "$tpl_has" = "no" ] && [ "$local_has" = "yes" ]; then
        echo -e "  ${BLUE}? EXTRA${NC}    $section — you have it, template doesn't"
        ((EXTRAS++))
      elif [ "$tpl_has" = "yes" ] && [ "$local_has" = "yes" ]; then
        echo -e "  ${NC}  ✓        $section"
      fi
    done

    # Deep config comparison
    echo ""
    echo -e "  ${BOLD}Key settings:${NC}"

    python3 << PYEOF
import json, sys

def load_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except:
        return {}

tpl = load_json("$TPL_CONFIG")
local = load_json("$OC_CONFIG")

checks = [
    ("agents.defaults.model", "Default model"),
    ("agents.defaults.heartbeat.enabled", "Heartbeat enabled"),
    ("agents.defaults.heartbeat.intervalMinutes", "Heartbeat interval"),
    ("agents.workspace.root", "Workspace root"),
    ("memory.sources", "Memory sources"),
    ("session.reset.mode", "Session reset mode"),
    ("session.reset.idleMinutes", "Session idle timeout"),
    ("channels.discord.enabled", "Discord enabled"),
    ("channels.discord.groupPolicy", "Discord group policy"),
    ("channels.discord.requireMention", "Discord require mention"),
    ("channels.telegram.enabled", "Telegram enabled"),
    ("channels.slack.enabled", "Slack enabled"),
    ("plugins.allow", "Allowed plugins"),
    ("skills.allowBundled", "Allowed bundled skills"),
]

def get_nested(d, path):
    keys = path.split(".")
    for k in keys:
        if isinstance(d, dict) and k in d:
            d = d[k]
        else:
            return None
    return d

for path, label in checks:
    tpl_val = get_nested(tpl, path)
    local_val = get_nested(local, path)

    if tpl_val is not None and local_val is None:
        print(f"  \033[0;32m+ MISSING\033[0m  {label}: template={json.dumps(tpl_val)}")
    elif tpl_val is not None and local_val is not None and tpl_val != local_val:
        # Truncate long values
        t = json.dumps(tpl_val)
        l = json.dumps(local_val)
        if len(t) > 60: t = t[:57] + "..."
        if len(l) > 60: l = l[:57] + "..."
        print(f"  \033[0;33m~ DIFFERS\033[0m  {label}")
        print(f"             template: {t}")
        print(f"             yours:    {l}")
    elif tpl_val is None and local_val is not None:
        l = json.dumps(local_val)
        if len(l) > 60: l = l[:57] + "..."
        print(f"  \033[0;34m? EXTRA\033[0m    {label}: yours={l}")

PYEOF
  fi

  echo ""
fi

# ── 3. Skills comparison ────────────────────────────────────────────────────

if [ "$CONFIG_ONLY" != true ]; then
  echo -e "${BOLD}━━━ Custom Skills ━━━${NC}"
  echo ""

  if [ -d "$TPL_SKILLS" ] && [ -d "$OC_SKILLS_CUSTOM" ]; then
    # Skills in template but not installed
    for skill_dir in "$TPL_SKILLS"/*/; do
      skill_name="$(basename "$skill_dir")"
      if [ ! -d "$OC_SKILLS_CUSTOM/$skill_name" ]; then
        echo -e "  ${GREEN}+ MISSING${NC}  $skill_name — template has it, you don't"
        if [ -f "$skill_dir/SKILL.md" ]; then
          desc=$(head -5 "$skill_dir/SKILL.md" | grep -i 'description\|#' | head -1 | sed 's/^#* *//')
          [ -n "$desc" ] && echo -e "    ${CYAN}→ $desc${NC}"
        fi
        ((MISSING++))
      fi
    done

    # Skills you have that template doesn't
    for skill_dir in "$OC_SKILLS_CUSTOM"/*/; do
      [ ! -d "$skill_dir" ] && continue
      skill_name="$(basename "$skill_dir")"
      if [ ! -d "$TPL_SKILLS/$skill_name" ]; then
        echo -e "  ${BLUE}? EXTRA${NC}    $skill_name"
        ((EXTRAS++))
      fi
    done
  else
    echo -e "  ${YELLOW}Skipping — missing template skills ($TPL_SKILLS) or local skills ($OC_SKILLS_CUSTOM)${NC}"
  fi

  echo ""
fi

# ── 4. Git config ───────────────────────────────────────────────────────────

if [ "$CONFIG_ONLY" != true ] && [ "$WORKSPACE_ONLY" != true ]; then
  echo -e "${BOLD}━━━ Git Config ━━━${NC}"
  echo ""

  recommended_git=(
    "init.defaultBranch:main"
    "pull.rebase:true"
    "push.autoSetupRemote:true"
    "fetch.prune:true"
    "rebase.autoStash:true"
    "diff.colorMoved:default"
    "core.excludesfile:$HOME/.gitignore_global"
  )

  for entry in "${recommended_git[@]}"; do
    key="${entry%%:*}"
    expected="${entry#*:}"
    actual=$(git config --global "$key" 2>/dev/null || echo "")

    if [ -z "$actual" ]; then
      echo -e "  ${GREEN}+ MISSING${NC}  $key (recommended: $expected)"
      ((MISSING++))
    elif [ "$actual" != "$expected" ]; then
      echo -e "  ${YELLOW}~ DIFFERS${NC}  $key: yours=$actual, recommended=$expected"
      ((CONFLICTS++))
    else
      echo -e "  ${NC}  ✓        $key = $actual"
    fi
  done

  # Check user identity
  git_name=$(git config --global user.name 2>/dev/null || echo "")
  git_email=$(git config --global user.email 2>/dev/null || echo "")
  [ -z "$git_name" ] && echo -e "  ${YELLOW}! WARNING${NC}  user.name not set"
  [ -z "$git_email" ] && echo -e "  ${YELLOW}! WARNING${NC}  user.email not set"

  # Global gitignore file
  if [ -f "$HOME/.gitignore_global" ]; then
    echo -e "  ${NC}  ✓        ~/.gitignore_global exists"
  else
    echo -e "  ${GREEN}+ MISSING${NC}  ~/.gitignore_global — run setup.sh to create it"
    ((MISSING++))
  fi

  echo ""
fi

# ── Summary ──────────────────────────────────────────────────────────────────

echo -e "${BOLD}━━━ Summary ━━━${NC}"
echo ""
echo -e "  ${GREEN}+ Missing (template has, you don't):${NC}  $MISSING"
echo -e "  ${YELLOW}~ Conflicts (different values):${NC}       $CONFLICTS"
echo -e "  ${BLUE}? Extras (you have, template doesn't):${NC} $EXTRAS"
echo ""

if [ $MISSING -eq 0 ] && [ $CONFLICTS -eq 0 ]; then
  echo -e "  ${GREEN}${BOLD}✓ Your setup matches the template!${NC}"
else
  echo -e "  Run with a coding agent or paste this output to your OpenClaw"
  echo -e "  to get help resolving differences."
fi
echo ""
