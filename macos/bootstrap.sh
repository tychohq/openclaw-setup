#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Mac Mini Bootstrap — One-liner entry point
# curl -fsSL mac.brennerspear.com | bash
# curl -fsSL mac.brennerspear.com | bash -s -- --handoff   # hand off to Claude Code after
# =============================================================================

REPO_URL="https://github.com/BrennerSpear/mac-mini-setup.git"
CLONE_DIR="$HOME/projects/mac-mini-setup"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║       Mac Mini Setup — Bootstrap             ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ── Step 0: Get sudo upfront ──────────────────────────────────────────────────
# When piped via curl|bash, stdin isn't a terminal so sudo can't prompt.
# We read the password from /dev/tty and enable passwordless sudo for the
# duration of setup, then remove it at the end.
SUDOERS_TMP="/etc/sudoers.d/mac-mini-setup-temp"
cleanup_sudo() {
  sudo rm -f "$SUDOERS_TMP" 2>/dev/null || true
}
trap cleanup_sudo EXIT

if ! sudo -n true 2>/dev/null; then
  echo ">>> This setup needs admin access. Enter your password (once):"
  sudo -v -S < /dev/tty
  if [ $? -ne 0 ]; then
    echo "❌ sudo authentication failed. Make sure this user has admin access."
    exit 1
  fi
fi

# Grant passwordless sudo for this user during setup
echo "$(whoami) ALL=(ALL) NOPASSWD: ALL" | sudo tee "$SUDOERS_TMP" > /dev/null
sudo chmod 0440 "$SUDOERS_TMP"
echo "  ✅ Sudo configured (no more password prompts during setup)"

# ── Step 1: Xcode Command Line Tools ──────────────────────────────────────────
if ! xcode-select -p &>/dev/null; then
  echo ">>> Installing Xcode Command Line Tools (required for git, compilers, etc.)..."
  echo "    A system dialog will appear. Click 'Install' and wait for it to finish."
  xcode-select --install

  # Wait for it to actually finish
  echo "    Waiting for Xcode CLT installation to complete..."
  until xcode-select -p &>/dev/null; do
    sleep 5
  done
  echo "    ✅ Xcode CLT installed"
else
  echo "✅ Xcode CLT already installed"
fi

# ── Step 2: Clone the repo ────────────────────────────────────────────────────
mkdir -p "$(dirname "$CLONE_DIR")"

if [ -d "$CLONE_DIR/.git" ]; then
  echo ">>> Repo already cloned at $CLONE_DIR — updating..."
  git -C "$CLONE_DIR" fetch origin
  git -C "$CLONE_DIR" reset --hard origin/main
else
  echo ">>> Cloning setup repo..."
  git clone "$REPO_URL" "$CLONE_DIR"
fi

# ── Step 3: Run the setup script ──────────────────────────────────────────────
echo ""
echo ">>> Running setup script..."
echo ""
chmod +x "$CLONE_DIR/setup.sh"
"$CLONE_DIR/setup.sh" "$@"
