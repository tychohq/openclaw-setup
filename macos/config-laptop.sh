#!/usr/bin/env bash
# Laptop profile for macos/setup.sh. Intentionally avoids personal/system
# preference changes, remote access, server behavior, and agent-stack setup.

SETUP_PROFILE_NAME="Mac Laptop"
NODE_VERSION="24"

TAPS=()
FORMULAE=(
  fnm
  mas
  python
  uv
)

# Keep this default list exact. Technical additions belong in the block below.
CASKS=(
  google-chrome
  1password
  raycast
  notion
  zoom
  spokenly
  chatgpt
  warp
  1password-cli
)

BUN_GLOBALS=()
NPM_GLOBALS=(
  "@openai/codex@0.121.0"
)
EXTENSIONS=()

if [ "${TECHNICAL:-false}" = true ]; then
  TAPS+=(steipete/tap)
  FORMULAE+=(
    fd
    ffmpeg
    fzf
    gh
    git-filter-repo
    htop
    imagemagick
    jq
    tmux
    wget
    steipete/tap/gogcli
    steipete/tap/gifgrep
    steipete/tap/goplaces
    steipete/tap/remindctl
  )
  CASKS+=(
    visual-studio-code
    docker-desktop
    sublime-text
    font-hack-nerd-font
  )
  BUN_GLOBALS+=(
    "typescript@5.9.3"
    "tsx@4.21.0"
    "vercel@50.9.5"
  )
  NPM_GLOBALS+=(
    "typescript@5.9.3"
    "tsx@4.21.0"
    "vercel@50.9.5"
  )
fi

GIT_USER_NAME=""
GIT_USER_EMAIL=""
APPLY_GIT_CONFIG=false
INSTALL_GUI_CLI_SYMLINKS="$TECHNICAL"
INSTALL_LAPTOP_TOOL_PATHS=true

APPLY_DOCK_DEFAULTS=false
APPLY_FINDER_DEFAULTS=false
APPLY_GLOBAL_DEFAULTS=false
APPLY_SCREENSHOT_DEFAULTS=false
APPLY_RAYCAST_HOTKEY=false
APPLY_SLEEP_DEFAULTS=false
APPLY_UPDATE_DEFAULTS=false
APPLY_REMOTE_ACCESS=false

DIRS=("$HOME/projects")

INSTALL_CLAUDE_CODE=true
INSTALL_OPENCLAW=false
OPENCLAW_GLOBALS=()
INSTALL_PREZTO=false
INSTALL_POWERLEVEL10K=false
INSTALL_RUST=false
POST_SCRIPTS=()

ALLOW_HANDOFF=false
SHOW_MINI_NEXT_STEPS=false
