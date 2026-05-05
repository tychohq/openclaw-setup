#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Mac Mini Bootstrap — One-liner entry point
# curl -fsSL mac.brennerspear.com | bash
# curl -fsSL mac.brennerspear.com | bash -s -- --handoff   # hand off to Claude Code after
#
# Non-interactive (password via env):
# curl -fsSL mac.brennerspear.com | SETUP_PASSWORD=mypass bash
# curl -fsSL mac.brennerspear.com | SETUP_PASSWORD=mypass bash -s -- --handoff
# =============================================================================

REPO_URL="https://github.com/tychohq/openclaw-setup.git"
CLONE_DIR="$HOME/projects/openclaw-setup"
CURRENT_STEP="starting"
SUDO_KEEPALIVE_PID=""

step() {
  CURRENT_STEP="$1"
  echo ""
  echo ">>> $1"
}

ok() {
  echo "  ✅ $1"
}

warn() {
  echo "  ⚠️  $1"
}

fail() {
  echo "❌ $1" >&2
}

cleanup() {
  if [ -n "$SUDO_KEEPALIVE_PID" ] && kill -0 "$SUDO_KEEPALIVE_PID" 2>/dev/null; then
    kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
  fi
  sudo -k 2>/dev/null || true
}

on_error() {
  local code=$?
  echo ""
  fail "Setup stopped during: $CURRENT_STEP"
  echo "   The last command returned exit code $code."
  echo "   Fix the issue above, then run the same command again."
  exit "$code"
}

trap cleanup EXIT
trap on_error ERR

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║       Mac Mini Setup — Bootstrap             ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

step "Checking that this is a Mac"
if [ "$(uname -s)" != "Darwin" ]; then
  fail "This bootstrap script only works on macOS."
  exit 1
fi
ok "macOS detected"

if [ "$(uname -m)" = "arm64" ]; then
  ok "Apple Silicon detected"
else
  warn "This flow is tested on Apple Silicon Macs. Continuing on $(uname -m)."
fi

step "Checking admin access"

# Support non-interactive sudo via SETUP_PASSWORD env var.
# This lets the script run unattended (e.g. over SSH to a fresh Mac).
if [ -n "${SETUP_PASSWORD:-}" ]; then
  echo "  Using SETUP_PASSWORD for non-interactive sudo..."
  if echo "$SETUP_PASSWORD" | sudo -S true 2>/dev/null; then
    ok "Admin access via SETUP_PASSWORD"
    export SETUP_PASSWORD  # propagate to setup.sh
  else
    fail "SETUP_PASSWORD was set but sudo authentication failed."
    exit 1
  fi
elif sudo -n true 2>/dev/null; then
  ok "Admin access already available"
else
  if [ ! -r /dev/tty ]; then
    fail "This script needs a Terminal window so it can ask for your password."
    fail "Or set SETUP_PASSWORD=<your-password> to run non-interactively."
    exit 1
  fi
  echo "  This setup needs your Mac password to install tools."
  if ! sudo -v < /dev/tty; then
    fail "Admin authentication failed. Make sure this user has admin access."
    exit 1
  fi
  ok "Password accepted"
fi

# Keep sudo alive in the background
while true; do
  if [ -n "${SETUP_PASSWORD:-}" ]; then
    echo "$SETUP_PASSWORD" | sudo -S true 2>/dev/null || exit
  else
    sudo -n true 2>/dev/null || exit
  fi
  sleep 60
done &
SUDO_KEEPALIVE_PID=$!

step "Checking Apple Command Line Tools"
if ! xcode-select -p &>/dev/null; then
  echo "  These tools are required for git, Homebrew, and compilers."
  echo "  A macOS pop-up may appear. Click Install, then come back here."
  xcode-select --install 2>/dev/null || true

  echo "  Waiting for Apple Command Line Tools to finish installing..."
  until xcode-select -p &>/dev/null; do
    sleep 5
  done
  ok "Apple Command Line Tools installed"
else
  ok "Apple Command Line Tools already installed"
fi

step "Preparing the setup repo"
mkdir -p "$(dirname "$CLONE_DIR")"

if [ -e "$CLONE_DIR" ] && [ ! -d "$CLONE_DIR/.git" ]; then
  fail "$CLONE_DIR already exists, but it is not a git repo. Move or rename it, then rerun."
  exit 1
fi

if [ -d "$CLONE_DIR/.git" ]; then
  echo "  Found an existing repo at $CLONE_DIR."
  if git -C "$CLONE_DIR" fetch origin && git -C "$CLONE_DIR" pull --ff-only; then
    ok "Repo updated"
  else
    warn "Local changes detected — leaving the repo as-is."
    echo "     If you want the newest version, commit/stash your changes and rerun."
  fi
else
  echo "  Downloading the setup repo to $CLONE_DIR ..."
  git clone "$REPO_URL" "$CLONE_DIR"
  ok "Repo cloned"
fi

step "Starting the full Mac mini setup"
echo "  Next you will see Homebrew, app, and tool installation steps."
echo "  This can take a while on a fresh Mac."
chmod +x "$CLONE_DIR/macos/setup.sh"
bash "$CLONE_DIR/macos/setup.sh" "$@"
