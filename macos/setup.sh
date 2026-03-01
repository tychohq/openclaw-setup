#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Mac Mini Setup — Idempotent, configurable, auditable
#
# Usage:
#   ./setup.sh                    # Full setup (no editor extensions)
#   ./setup.sh --dry-run          # Audit what would change
#   ./setup.sh --with-extensions  # Full setup + editor extensions
#   ./setup.sh --extensions-only  # Install only editor extensions
#   ./setup.sh --help
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Parse arguments ──────────────────────────────────────────────────────────

print_usage() {
  cat <<'EOF'
Usage: setup.sh [OPTIONS]

Options:
  --dry-run, -n       Audit current system and report what would change
  --extensions-only   Install only editor extensions and exit
  --with-extensions   Include editor extensions in full setup
  --skip-extensions   Skip editor extensions (default)
  --config FILE       Use a custom config file (default: config.sh)
  --handoff           Launch Claude Code after setup to finish interactively (default)
  --no-handoff        Skip Claude Code handoff
  --help, -h          Show this help
EOF
}

DRY_RUN=false
EXTENSIONS_ONLY=false
SKIP_EXTENSIONS=true
HANDOFF=true
CONFIG_FILE="$SCRIPT_DIR/config.sh"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run|-n)     DRY_RUN=true ;;
    --extensions-only) EXTENSIONS_ONLY=true ;;
    --with-extensions) SKIP_EXTENSIONS=false ;;
    --skip-extensions) SKIP_EXTENSIONS=true ;;
    --handoff)        HANDOFF=true ;;
    --no-handoff)     HANDOFF=false ;;
    --config)         shift; CONFIG_FILE="$1" ;;
    --help|-h)        print_usage; exit 0 ;;
    *)                echo "Unknown argument: $1" >&2; print_usage >&2; exit 1 ;;
  esac
  shift
done

if [ "$DRY_RUN" = true ] && [ "$EXTENSIONS_ONLY" = true ]; then
  echo "Cannot combine --dry-run with --extensions-only." >&2
  exit 1
fi

# ── Load config ──────────────────────────────────────────────────────────────

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Config file not found: $CONFIG_FILE" >&2
  echo "Copy config.sh.example to config.sh and customize it." >&2
  exit 1
fi

# shellcheck source=config.sh
source "$CONFIG_FILE"

# ── Reporting helpers ────────────────────────────────────────────────────────

INSTALLED_ITEMS=()
SKIPPED_ITEMS=()
FAILED_ITEMS=()

record_installed() { INSTALLED_ITEMS+=("$1"); echo "  ✅ $1"; }
record_skipped()   { SKIPPED_ITEMS+=("$1 :: $2"); echo "  ⏭️  $1 ($2)"; }
record_failed()    { FAILED_ITEMS+=("$1 :: $2"); echo "  ❌ $1 ($2)"; }

last_non_empty_line() {
  printf '%s\n' "$1" | awk 'NF { line=$0 } END { print line }'
}

reason_from_output() {
  local reason
  reason="$(last_non_empty_line "$1")"
  printf '%s' "${reason:-no error output}"
}

looks_like_already_installed() {
  printf '%s\n' "$1" | grep -Eqi \
    'already (installed|exists|linked|up[ -]?to[ -]?date|tapped|running)|is installed|nothing to do|up to date'
}

# Run a command, recording success/failure
run_cmd() {
  local item="$1"; shift
  local output
  if output="$("$@" 2>&1)"; then
    record_installed "$item"
    return 0
  fi
  local code=$?
  if looks_like_already_installed "$output"; then
    record_skipped "$item" "$(reason_from_output "$output")"
    return 0
  fi
  record_failed "$item" "exit $code: $(reason_from_output "$output")"
  printf '%s\n' "$output" | sed 's/^/    /'
  return 1
}

print_list() {
  local title="$1"; shift
  local filtered=()
  for item in "$@"; do [ -n "$item" ] && filtered+=("$item"); done
  echo ""
  echo "$title (${#filtered[@]})"
  if [ "${#filtered[@]}" -eq 0 ]; then
    echo "  (none)"
    return
  fi
  for item in "${filtered[@]}"; do echo "  - $item"; done
}

print_summary() {
  echo ""
  echo "════════════════════════════════════════════════"
  echo "  Setup Summary"
  echo "════════════════════════════════════════════════"
  print_list "Installed / updated" "${INSTALLED_ITEMS[@]-}"
  print_list "Skipped (already present)" "${SKIPPED_ITEMS[@]-}"
  print_list "Failed" "${FAILED_ITEMS[@]-}"
  echo ""
  if [ "${#FAILED_ITEMS[@]}" -gt 0 ]; then
    echo "⚠️  Completed with ${#FAILED_ITEMS[@]} failure(s). Review above."
    return 1
  fi
  echo "✅ Setup complete with no failures."
  return 0
}

# ── Brew helpers ─────────────────────────────────────────────────────────────

set_brew_env() {
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    return 0
  fi
  command -v brew &>/dev/null && eval "$(brew shellenv)" && return 0
  return 1
}

bun_global_version() {
  local pkg="$1"
  local pj="$HOME/.bun/install/global/node_modules/$pkg/package.json"
  if [ -f "$pj" ]; then
    sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$pj" | head -n1
  fi
  return 0
}

# ══════════════════════════════════════════════════════════════════════════════
# DRY RUN MODE
# ══════════════════════════════════════════════════════════════════════════════

if [ "$DRY_RUN" = true ]; then
  echo "═══ Dry Run — No changes will be made ═══"
  echo ""

  # Xcode CLT
  if xcode-select -p &>/dev/null; then
    echo "  ✅ Xcode CLT"
  else
    echo "  ❓ Xcode CLT — would install"
  fi

  # Homebrew
  if command -v brew &>/dev/null; then
    echo "  ✅ Homebrew ($(brew --version 2>/dev/null | head -n1))"
    brew_formulae="$(brew list --formula --versions 2>/dev/null || true)"
    brew_casks="$(brew list --cask --versions 2>/dev/null || true)"
    brew_taps="$(brew tap 2>/dev/null || true)"
  else
    echo "  ❓ Homebrew — would install"
    brew_formulae=""
    brew_casks=""
    brew_taps=""
  fi

  # Taps
  for tap in "${TAPS[@]-}"; do
    [ -z "$tap" ] && continue
    if printf '%s\n' "$brew_taps" | grep -Fxq "$tap"; then
      echo "  ✅ tap $tap"
    else
      echo "  ❓ tap $tap — would add"
    fi
  done

  # Formulae
  for formula in "${FORMULAE[@]-}"; do
    [ -z "$formula" ] && continue
    if printf '%s\n' "$brew_formulae" | awk '{print $1}' | grep -Fxq "$formula"; then
      echo "  ✅ $formula"
    else
      echo "  ❓ $formula — would install"
    fi
  done

  # Casks
  for cask in "${CASKS[@]-}"; do
    [ -z "$cask" ] && continue
    if printf '%s\n' "$brew_casks" | awk '{print $1}' | grep -Fxq "$cask"; then
      echo "  ✅ $cask"
    else
      echo "  ❓ $cask — would install"
    fi
  done

  # Bun
  if command -v bun &>/dev/null; then
    echo "  ✅ Bun ($(bun --version 2>/dev/null))"
  else
    echo "  ❓ Bun — would install"
  fi

  # Bun globals
  for spec in "${BUN_GLOBALS[@]-}"; do
    [ -z "$spec" ] && continue
    local_pkg="${spec%@*}"
    local_ver="${spec##*@}"
    cur="$(bun_global_version "$local_pkg")"
    if [ "$cur" = "$local_ver" ]; then
      echo "  ✅ $local_pkg@$cur"
    elif [ -n "$cur" ]; then
      echo "  🔄 $local_pkg — current=$cur want=$local_ver"
    else
      echo "  ❓ $local_pkg@$local_ver — would install"
    fi
  done

  # Node
  if command -v fnm &>/dev/null && fnm ls 2>/dev/null | grep -q "v${NODE_VERSION}"; then
    echo "  ✅ Node v${NODE_VERSION} (via fnm)"
  else
    echo "  ❓ Node v${NODE_VERSION} — would install via fnm"
  fi

  # OpenClaw
  if [ "${INSTALL_OPENCLAW:-false}" = true ]; then
    if command -v openclaw &>/dev/null; then
      echo "  ✅ OpenClaw"
    else
      echo "  ❓ OpenClaw — would install"
    fi
  fi

  echo ""
  echo "Run without --dry-run to apply."
  exit 0
fi

# ══════════════════════════════════════════════════════════════════════════════
# EXTENSIONS ONLY MODE
# ══════════════════════════════════════════════════════════════════════════════

install_editor_extensions() {
  if [ "$SKIP_EXTENSIONS" = true ]; then
    record_skipped "editor extensions" "use --with-extensions to include"
    return 0
  fi

  for editor_cmd in code cursor; do
    if ! command -v "$editor_cmd" &>/dev/null; then
      record_skipped "$editor_cmd extensions" "$editor_cmd CLI not found"
      continue
    fi

    local ext_list
    if ! ext_list="$($editor_cmd --list-extensions 2>/dev/null)"; then
      record_failed "$editor_cmd extensions" "failed to list extensions"
      continue
    fi

    for ext in "${EXTENSIONS[@]-}"; do
      [ -z "$ext" ] && continue
      if printf '%s\n' "$ext_list" | grep -Fxq "$ext"; then
        record_skipped "$editor_cmd ext $ext" "already installed"
      else
        run_cmd "$editor_cmd ext $ext" "$editor_cmd" --install-extension "$ext" --force || true
      fi
    done
  done
}

if [ "$EXTENSIONS_ONLY" = true ]; then
  SKIP_EXTENSIONS=false
  install_editor_extensions
  print_summary
  exit $?
fi

# ══════════════════════════════════════════════════════════════════════════════
# FULL SETUP
# ══════════════════════════════════════════════════════════════════════════════

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║          Mac Mini Setup — Full Run           ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ── 1. Xcode CLT ─────────────────────────────────────────────────────────────

if xcode-select -p &>/dev/null; then
  record_skipped "Xcode CLT" "already installed"
else
  echo ">>> Installing Xcode Command Line Tools..."
  xcode-select --install 2>/dev/null || true
  echo "    Waiting for Xcode CLT installation to complete..."
  until xcode-select -p &>/dev/null; do
    sleep 5
  done
  if xcode-select -p &>/dev/null; then
    record_installed "Xcode CLT"
  else
    record_failed "Xcode CLT" "still not found after install"
  fi
fi

# ── 2. Homebrew ───────────────────────────────────────────────────────────────

if command -v brew &>/dev/null; then
  record_skipped "Homebrew" "already installed"
else
  echo ">>> Installing Homebrew..."
  echo "    (requires admin/sudo access)"
  if NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" 2>&1; then
    record_installed "Homebrew"
  else
    record_failed "Homebrew" "installation failed"
  fi
fi

if set_brew_env; then
  record_installed "Homebrew PATH"
else
  record_failed "Homebrew PATH" "could not set up brew in PATH"
fi

# Bail if brew is not available — everything below depends on it
if ! command -v brew &>/dev/null; then
  echo ""
  echo "❌ Homebrew is not available. Cannot continue."
  echo ""
  echo "   Common fixes:"
  echo "   1. Make sure this user has admin/sudo access"
  echo "   2. Run: sudo dseditgroup -o edit -a \$(whoami) -t user admin"
  echo "   3. Then re-run this script"
  echo ""
  print_summary
  exit 1
fi

# ── 3. Taps ───────────────────────────────────────────────────────────────────

echo ">>> Homebrew taps..."
for tap in "${TAPS[@]-}"; do
  [ -z "$tap" ] && continue
  if brew tap 2>/dev/null | grep -Fxq "$tap"; then
    record_skipped "tap $tap" "already tapped"
  else
    run_cmd "tap $tap" brew tap "$tap" || true
  fi
done

# ── 4. Formulae ───────────────────────────────────────────────────────────────

echo ">>> Homebrew formulae..."
for formula in "${FORMULAE[@]-}"; do
  [ -z "$formula" ] && continue
  if brew list --formula --versions "$formula" &>/dev/null; then
    record_skipped "$formula" "already installed"
  else
    run_cmd "$formula" brew install "$formula" || true
  fi
done

# ── 5. Casks ──────────────────────────────────────────────────────────────────

echo ">>> Homebrew casks..."
for cask in "${CASKS[@]-}"; do
  [ -z "$cask" ] && continue
  if brew list --cask --versions "$cask" &>/dev/null; then
    record_skipped "$cask" "already installed"
  else
    run_cmd "$cask" brew install --cask "$cask" || true
  fi
done

# ── 5b. CLI symlinks for GUI apps ────────────────────────────────────────────

# Sublime Text → subl
SUBL_BIN="/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl"
if [ -f "$SUBL_BIN" ] && ! command -v subl &>/dev/null; then
  ln -sf "$SUBL_BIN" /usr/local/bin/subl 2>/dev/null || sudo ln -sf "$SUBL_BIN" /usr/local/bin/subl
  record_installed "subl symlink"
elif command -v subl &>/dev/null; then
  record_skipped "subl symlink" "already available"
fi

# VS Code → code (usually handled by VS Code itself, but ensure it)
VSCODE_BIN="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
if [ -f "$VSCODE_BIN" ] && ! command -v code &>/dev/null; then
  ln -sf "$VSCODE_BIN" /usr/local/bin/code 2>/dev/null || sudo ln -sf "$VSCODE_BIN" /usr/local/bin/code
  record_installed "code symlink"
elif command -v code &>/dev/null; then
  record_skipped "code symlink" "already available"
fi

# ── 6. Bun ────────────────────────────────────────────────────────────────────

if command -v bun &>/dev/null; then
  record_skipped "Bun" "already installed"
else
  echo ">>> Installing Bun..."
  if curl -fsSL https://bun.sh/install | bash 2>&1; then
    record_installed "Bun"
  else
    record_failed "Bun" "installation failed"
  fi
fi
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# ── 7. Bun global packages ───────────────────────────────────────────────────

echo ">>> Bun global packages..."
for spec in "${BUN_GLOBALS[@]-}"; do
  [ -z "$spec" ] && continue
  pkg="${spec%@*}"
  desired="${spec##*@}"
  current="$(bun_global_version "$pkg")"
  if [ "$current" = "$desired" ]; then
    record_skipped "bun:$pkg" "already at $desired"
  else
    run_cmd "bun:$pkg@$desired" bun install -g --exact "$spec" || true
  fi
done

# ── 8. Node via fnm ──────────────────────────────────────────────────────────

echo ">>> Node.js via fnm..."
if command -v fnm &>/dev/null; then
  # Install the desired version first (before fnm env, which tries to activate "default")
  if fnm ls 2>/dev/null | grep -q "v${NODE_VERSION}"; then
    record_skipped "Node v${NODE_VERSION}" "already installed"
  else
    if fnm install "$NODE_VERSION" 2>&1; then
      record_installed "Node v${NODE_VERSION}"
    else
      record_failed "Node v${NODE_VERSION}" "fnm install failed"
    fi
  fi

  # Set as default, then activate
  fnm default "$NODE_VERSION" 2>/dev/null || true
  eval "$(fnm env --use-on-cd --version-file-strategy=recursive --shell bash 2>/dev/null)" || true
  fnm use "$NODE_VERSION" 2>/dev/null || true

  if fnm current 2>/dev/null | grep -q "${NODE_VERSION}"; then
    record_installed "fnm default Node v${NODE_VERSION}"
  else
    record_failed "fnm default" "could not activate v${NODE_VERSION}"
  fi
else
  record_failed "fnm" "not found — install fnm first (included in FORMULAE)"
fi

# ── 8b. npm → bun wrapper ─────────────────────────────────────────────────────
# Replace npm with a wrapper that reminds you to use bun instead.
# The real npm is preserved as npm-real for escape-hatch use.

echo ">>> Setting up npm → bun redirect wrapper..."
NPM_PATH="$(command -v npm 2>/dev/null || true)"
if [ -n "$NPM_PATH" ] && [ -f "$NPM_PATH" ]; then
  # Check if it's already our wrapper (starts with #!/bin/bash and mentions bun)
  if head -2 "$NPM_PATH" 2>/dev/null | grep -q "bun"; then
    record_skipped "npm wrapper" "already installed"
  else
    NPM_DIR="$(dirname "$NPM_PATH")"
    NPM_REAL="$NPM_DIR/npm-real"
    # Preserve original npm as npm-real (if not already done)
    if [ ! -e "$NPM_REAL" ]; then
      run_cmd "npm-real backup" cp "$NPM_PATH" "$NPM_REAL"
    fi
    # Write the wrapper
    cat > "$NPM_PATH" << 'WRAPPER'
#!/bin/bash
echo "❌ Don't use npm. Use bun."
echo "   bun install / bun install -g <pkg> / bun run <script>"
echo ""
echo "   If you REALLY can't use bun, run: npm-real $@"
exit 1
WRAPPER
    chmod +x "$NPM_PATH"
    record_installed "npm → bun wrapper"
  fi
else
  record_skipped "npm wrapper" "npm not found (Node may not be installed yet)"
fi

# ── 9. Rust (optional) ───────────────────────────────────────────────────────

if [ "${INSTALL_RUST:-false}" = true ]; then
  if command -v rustup &>/dev/null; then
    record_skipped "Rust" "already installed"
  else
    echo ">>> Installing Rust..."
    if curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y 2>&1; then
      record_installed "Rust"
      [ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
    else
      record_failed "Rust" "installation failed"
    fi
  fi
fi

# ── 10. Git config ───────────────────────────────────────────────────────────

echo ""
echo ">>> Git configuration..."

# Global gitignore
GITIGNORE_SRC="$SCRIPT_DIR/config/gitignore_global"
GITIGNORE_DEST="$HOME/.gitignore_global"
if [ -f "$GITIGNORE_SRC" ]; then
  if [ -f "$GITIGNORE_DEST" ]; then
    record_skipped "gitignore_global" "already exists"
  else
    cp "$GITIGNORE_SRC" "$GITIGNORE_DEST"
    git config --global core.excludesfile "$GITIGNORE_DEST"
    record_installed "gitignore_global"
  fi
fi

# Git defaults (idempotent — safe to re-run)
git config --global init.defaultBranch main
git config --global pull.rebase true
git config --global push.autoSetupRemote true
git config --global fetch.prune true
git config --global diff.colorMoved default
git config --global rebase.autoStash true
record_installed "git defaults (init.defaultBranch, pull.rebase, push.autoSetupRemote, etc.)"

# User info (only if set in config.sh)
if [ -n "${GIT_USER_NAME:-}" ]; then
  git config --global user.name "$GIT_USER_NAME"
  record_installed "git user.name → $GIT_USER_NAME"
else
  if [ -z "$(git config --global user.name 2>/dev/null)" ]; then
    record_skipped "git user.name" "not set — configure in config.sh or run: git config --global user.name 'Your Name'"
  else
    record_skipped "git user.name" "already set to '$(git config --global user.name)'"
  fi
fi

if [ -n "${GIT_USER_EMAIL:-}" ]; then
  git config --global user.email "$GIT_USER_EMAIL"
  record_installed "git user.email → $GIT_USER_EMAIL"
else
  if [ -z "$(git config --global user.email 2>/dev/null)" ]; then
    record_skipped "git user.email" "not set — configure in config.sh or run: git config --global user.email 'you@example.com'"
  else
    record_skipped "git user.email" "already set to '$(git config --global user.email)'"
  fi
fi

# ── 11. Shell setup (optional) ───────────────────────────────────────────────

if [ "${INSTALL_PREZTO:-false}" = true ]; then
  if [ -d "$HOME/.zprezto" ]; then
    record_skipped "Prezto" "already installed"
  else
    run_cmd "Prezto" git clone --recursive https://github.com/sorin-ionescu/prezto.git "$HOME/.zprezto" || true
  fi
fi

if [ "${INSTALL_POWERLEVEL10K:-false}" = true ]; then
  if [ -d "$HOME/powerlevel10k" ]; then
    record_skipped "Powerlevel10k" "already installed"
  else
    run_cmd "Powerlevel10k" git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$HOME/powerlevel10k" || true
  fi
fi

# ── 12. OpenClaw (optional) ──────────────────────────────────────────────────

if [ "${INSTALL_OPENCLAW:-false}" = true ]; then
  echo ">>> Installing OpenClaw..."
  for spec in "${OPENCLAW_GLOBALS[@]-}"; do
    [ -z "$spec" ] && continue
    pkg="${spec%@*}"
    run_cmd "openclaw:$pkg" bun install -g "$spec" || true
  done

  # Install Playwright browsers for agent-browser
  if command -v bunx &>/dev/null; then
    echo ">>> Installing Playwright browsers..."
    run_cmd "Playwright Chromium" bunx playwright install chromium || true
  fi

  # Install Claude Code
  if ! command -v claude &>/dev/null; then
    echo ">>> Installing Claude Code..."
    if curl -fsSL https://claude.ai/install.sh | bash 2>&1; then
      record_installed "Claude Code"
    else
      record_failed "Claude Code" "installation failed"
    fi
  else
    record_skipped "Claude Code" "already installed"
  fi

  # Non-interactive OpenClaw configuration
  # Look for secrets files in the repo root or specified via OPENCLAW_SECRETS_JSON / OPENCLAW_SECRETS_ENV
  OC_CONFIG="${OPENCLAW_SECRETS_JSON:-$REPO_DIR/openclaw-secrets.json}"
  OC_ENV="${OPENCLAW_SECRETS_ENV:-$REPO_DIR/openclaw-secrets.env}"
  OC_AUTH="${OPENCLAW_SECRETS_AUTH:-$REPO_DIR/openclaw-auth-profiles.json}"

  # Auto-create .env from template if it doesn't exist yet
  if [ ! -f "$OC_ENV" ] && [ -f "$REPO_DIR/config/openclaw-env.template" ]; then
    echo ">>> Creating openclaw-secrets.env from template..."
    cp "$REPO_DIR/config/openclaw-env.template" "$OC_ENV"
    record_installed "openclaw-secrets.env (from template — fill in your API keys)"
    echo "  ℹ️  Edit $OC_ENV with your API keys, then re-run setup or run:"
    echo "     scripts/setup-openclaw.sh --env $OC_ENV"
  fi

  if [ -f "$OC_CONFIG" ]; then
    echo ">>> Configuring OpenClaw from secrets file..."
    SETUP_ARGS=(--config "$OC_CONFIG")
    [ -f "$OC_ENV" ] && SETUP_ARGS+=(--env "$OC_ENV")
    [ -f "$OC_AUTH" ] && SETUP_ARGS+=(--auth-profiles "$OC_AUTH")
    if "$SCRIPT_DIR/scripts/setup-openclaw.sh" "${SETUP_ARGS[@]}"; then
      record_installed "OpenClaw config"
    else
      record_failed "OpenClaw config" "setup-openclaw.sh failed"
    fi
  else
    echo "  ⏭️  No openclaw-secrets.json found — skipping config."
    echo "     Run: scripts/setup-openclaw.sh --config <your-secrets.json>"
    record_skipped "OpenClaw config" "no secrets file (see config/ templates)"
  fi

  # Bootstrap workspace, skills, and cron
  if [ -x "$SCRIPT_DIR/scripts/bootstrap-openclaw-workspace.sh" ]; then
    echo ">>> Bootstrapping OpenClaw workspace..."
    "$SCRIPT_DIR/scripts/bootstrap-openclaw-workspace.sh" || record_failed "OpenClaw workspace" "bootstrap failed"
  fi
fi

# ── 13. macOS Defaults ───────────────────────────────────────────────────────

echo ">>> Applying macOS defaults..."

if [ "${APPLY_DOCK_DEFAULTS:-false}" = true ]; then
  # Clear default dock items and only add what we installed
  if [ "${DOCK_CLEAR_DEFAULT:-true}" = true ]; then
    defaults write com.apple.dock persistent-apps -array 2>/dev/null || true
    defaults write com.apple.dock persistent-others -array 2>/dev/null || true
    record_installed "dock: cleared default items"

    # Add back apps that are actually installed
    DOCK_APPS=("${DOCK_KEEP_APPS[@]-}")
    if [ ${#DOCK_APPS[@]} -eq 0 ]; then
      # Default: add Finder, Chrome, Terminal (and Warp if installed)
      DOCK_APPS=("/System/Applications/Finder.app")
      [ -d "/Applications/Google Chrome.app" ] && DOCK_APPS+=("/Applications/Google Chrome.app")
      [ -d "/Applications/Warp.app" ] && DOCK_APPS+=("/Applications/Warp.app")
      [ -d "/Applications/Cursor.app" ] && DOCK_APPS+=("/Applications/Cursor.app")
      [ ! -d "/Applications/Warp.app" ] && DOCK_APPS+=("/System/Applications/Utilities/Terminal.app")
    fi
    for app in "${DOCK_APPS[@]}"; do
      if [ -d "$app" ]; then
        defaults write com.apple.dock persistent-apps -array-add \
          "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>$app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>" 2>/dev/null || true
      fi
    done
    record_installed "dock: added installed apps"
  fi

  run_cmd "dock: autohide" defaults write com.apple.dock autohide -bool "${DOCK_AUTOHIDE:-true}" || true
  run_cmd "dock: orientation" defaults write com.apple.dock orientation -string "${DOCK_ORIENTATION:-right}" || true
  run_cmd "dock: tilesize" defaults write com.apple.dock tilesize -int "${DOCK_TILESIZE:-43}" || true
  run_cmd "dock: magnification" defaults write com.apple.dock magnification -bool "${DOCK_MAGNIFICATION:-true}" || true
  run_cmd "dock: show-recents" defaults write com.apple.dock show-recents -bool "${DOCK_SHOW_RECENTS:-false}" || true
  run_cmd "dock: no launch animation" defaults write com.apple.dock launchanim -bool false || true
  killall Dock 2>/dev/null || true
fi

if [ "${APPLY_FINDER_DEFAULTS:-false}" = true ]; then
  run_cmd "finder: show hidden files" defaults write com.apple.finder AppleShowAllFiles -bool true || true
  killall Finder 2>/dev/null || true
fi

if [ "${APPLY_GLOBAL_DEFAULTS:-false}" = true ]; then
  run_cmd "global: dark mode" defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark" || true
  run_cmd "global: no beep feedback" defaults write NSGlobalDomain "com.apple.sound.beep.feedback" -bool false || true
  run_cmd "global: double-click maximize" defaults write NSGlobalDomain AppleActionOnDoubleClick -string "Maximize" || true
  run_cmd "global: Fahrenheit" defaults write NSGlobalDomain AppleTemperatureUnit -string "Fahrenheit" || true
fi

if [ "${APPLY_SCREENSHOT_DEFAULTS:-false}" = true ]; then
  mkdir -p "$HOME/Documents/Screenshots"
  run_cmd "screenshots: location" defaults write com.apple.screencapture location -string "$HOME/Documents/Screenshots" || true
fi

# ── 13b. Disable Spotlight hotkey (Cmd+Space) so Raycast can use it ──────────

if [ "${APPLY_RAYCAST_HOTKEY:-true}" = true ]; then
  echo ">>> Disabling Spotlight Cmd+Space (Raycast will claim it)..."
  # Disable Spotlight's Cmd+Space shortcut via keyboard shortcuts plist
  # AppleSymbolicHotKeys key 64 = Spotlight Search, key 65 = Finder Search
  run_cmd "spotlight: disable Cmd+Space" defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 '{ enabled = 0; value = { parameters = (65535, 49, 1048576); type = "standard"; }; }' || true
  run_cmd "spotlight: disable Cmd+Alt+Space" defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 65 '{ enabled = 0; value = { parameters = (65535, 49, 1572864); type = "standard"; }; }' || true
  echo "  ℹ️  Open Raycast after setup and set Cmd+Space as its hotkey in preferences."
fi

# ── 14. Create directories ───────────────────────────────────────────────────

echo ">>> Creating directories..."
for dir in "${DIRS[@]-}"; do
  [ -z "$dir" ] && continue
  if [ -d "$dir" ]; then
    record_skipped "dir $dir" "already exists"
  else
    run_cmd "dir $dir" mkdir -p "$dir" || true
  fi
done

# ── 15. Editor extensions ────────────────────────────────────────────────────

install_editor_extensions

# ── 16. Post scripts ─────────────────────────────────────────────────────────

for script in "${POST_SCRIPTS[@]-}"; do
  [ -z "$script" ] && continue
  script_path="$SCRIPT_DIR/$script"
  if [ -x "$script_path" ]; then
    echo ">>> Running post script: $script"
    "$script_path" || record_failed "post script $script" "exited non-zero"
  else
    record_skipped "post script $script" "not found or not executable"
  fi
done

# ── Done ──────────────────────────────────────────────────────────────────────

print_summary

# ── Generate handoff context ──────────────────────────────────────────────────
# Extract commented-out items from config so Claude Code knows what's available

SKIPPED_FORMULAE=()
while IFS= read -r line; do
  pkg="$(echo "$line" | sed 's/#[[:space:]]*//' | awk '{print $1}')"
  [ -n "$pkg" ] && SKIPPED_FORMULAE+=("$pkg")
done < <(grep '^[[:space:]]*#[[:space:]]*[a-z]' "$CONFIG_FILE" | grep -A0 -B0 'FORMULAE\|# [a-z]' 2>/dev/null || true)

# Actually, let's parse it properly from the config arrays
SKIPPED_CONFIG_ITEMS=""
in_array=""
while IFS= read -r line; do
  # Detect array starts
  if echo "$line" | grep -qE '^(FORMULAE|CASKS|BUN_GLOBALS|OPENCLAW_GLOBALS)='; then
    in_array="$(echo "$line" | cut -d= -f1)"
    continue
  fi
  # Detect array end
  if [ -n "$in_array" ] && echo "$line" | grep -q ')'; then
    in_array=""
    continue
  fi
  # Inside an array, look for commented items
  if [ -n "$in_array" ]; then
    commented="$(echo "$line" | grep '^[[:space:]]*#[[:space:]]*[a-z"@]' | sed 's/^[[:space:]]*#[[:space:]]*//' | sed 's/[[:space:]]*#.*//' | tr -d '"' || true)"
    if [ -n "$commented" ]; then
      SKIPPED_CONFIG_ITEMS="${SKIPPED_CONFIG_ITEMS}  - [${in_array}] ${commented}\n"
    fi
  fi
done < "$CONFIG_FILE"

echo ""
echo "Next steps:"
echo "  1. Sign into apps: 1Password, Raycast, Slack, Discord, Tailscale, etc."
echo "  2. CLI logins: gh auth login, vercel login"
echo "  3. Configure SSH: add keys to ~/.ssh/"
if [ "${INSTALL_OPENCLAW:-false}" = true ]; then
  if [ ! -f "${OC_CONFIG:-}" ]; then
    echo "  4. Set up OpenClaw:"
    echo "     cp config/openclaw-config.template.json openclaw-secrets.json"
    echo "     cp config/openclaw-env.template openclaw-secrets.env"
    echo "     # Fill in your API keys, then:"
    echo "     scripts/setup-openclaw.sh --config openclaw-secrets.json --env openclaw-secrets.env"
  else
    echo "  4. Verify OpenClaw: scripts/setup-openclaw.sh --check"
  fi
fi
echo ""

# ── Handoff to Claude Code ───────────────────────────────────────────────────

if [ "$HANDOFF" = true ]; then
  # Install Claude Code if not already present
  if ! command -v claude &>/dev/null; then
    echo ">>> Installing Claude Code for handoff..."
    if curl -fsSL https://claude.ai/install.sh | bash 2>&1; then
      export PATH="$HOME/.local/bin:$PATH"
      record_installed "Claude Code (for handoff)"
    else
      echo "⚠️  Claude Code installation failed. Install manually:"
      echo "    curl -fsSL https://claude.ai/install.sh | bash"
      echo "    claude --dangerously-skip-permissions --prompt \"\$(cat $SCRIPT_DIR/scripts/handoff-prompt.md)\""
    fi
  fi

  if command -v claude &>/dev/null; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Handing off to Claude Code to finish setup..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Write handoff context to a file Claude Code can read
    HANDOFF_FILE="$SCRIPT_DIR/.handoff-context.md"
    cat > "$HANDOFF_FILE" << HANDOFF_EOF
$(cat "$SCRIPT_DIR/scripts/handoff-prompt.md")

## What was installed
$(printf '%s\n' "${INSTALLED_ITEMS[@]-}" | sed 's/^/- /')

## What failed
$(printf '%s\n' "${FAILED_ITEMS[@]-}" | sed 's/^/- /')

## Available but not installed (commented out in config.sh)
These are available to install if the user wants them:
$(echo -e "$SKIPPED_CONFIG_ITEMS")

## Config file location
$SCRIPT_DIR/config.sh — edit this to add/remove packages permanently
HANDOFF_EOF

    # Check if Claude is authenticated
    if claude --version &>/dev/null && claude -p "say ok" &>/dev/null 2>&1; then
      # Authenticated — launch with the handoff prompt
      exec claude --dangerously-skip-permissions -p "Read $HANDOFF_FILE and follow its instructions. Start by checking what's already configured and ask what to tackle first."
    else
      # Not authenticated — launch interactively so user can log in
      echo "  Claude Code needs authentication first."
      echo "  After logging in, run:"
      echo ""
      echo "    claude -p \"Read $HANDOFF_FILE and follow its instructions.\""
      echo ""
      exec claude
    fi
  fi
fi
