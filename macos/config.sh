#!/usr/bin/env bash
# =============================================================================
# config.sh — Customize what gets installed
#
# Fork this repo and edit this file to match your team's needs.
# Everything is opt-in. Comment out what you don't want.
# =============================================================================

# ── Git config ────────────────────────────────────────────────────────────────
# Leave blank to skip (or fill in during bootstrap)
GIT_USER_NAME=""
GIT_USER_EMAIL=""

# ── Node version (via fnm) ────────────────────────────────────────────────────
NODE_VERSION="24"

# ── Homebrew Taps ─────────────────────────────────────────────────────────────
TAPS=(
  # steipete/tap           # gifgrep, gogcli, remindctl, bird
  # supabase/tap           # supabase CLI
  # tursodatabase/tap      # turso CLI
)

# ── Homebrew Formulae (CLI tools) ─────────────────────────────────────────────
FORMULAE=(
  # Core dev tools
  fd                       # fast find alternative
  ffmpeg                   # media processing
  fnm                      # fast Node version manager
  fzf                      # fuzzy finder
  gh                       # GitHub CLI
  git-filter-repo          # git history rewriting
  htop                     # system monitor
  imagemagick              # image processing
  jq                       # JSON processing
  mas                      # Mac App Store CLI
  tmux                     # terminal multiplexer
  uv                       # fast Python package manager
  wget                     # HTTP downloads

  # Databases
  # postgresql@16
  # redis

  # Languages / runtimes (beyond Node)
  # go
  # python@3.12

  # Optional
  # helm                   # Kubernetes package manager
  # minikube               # local Kubernetes
  # poppler                # PDF tools
  # syncthing              # file sync
)

# ── Homebrew Casks (GUI apps) ─────────────────────────────────────────────────
CASKS=(
  # Browsers
  arc
  google-chrome

  # Dev tools
  cursor
  visual-studio-code
  docker-desktop
  sublime-text
  warp                     # terminal
  # postman

  # Communication
  slack
  discord
  zoom
  # telegram
  # whatsapp

  # Productivity
  1password
  1password-cli
  raycast
  notion
  # asana
  # linear-linear
  # todoist
  # rectangle              # window management
  # figma

  # AI
  chatgpt
  claude

  # Media
  spotify
  vlc
  # obs

  # System
  tailscale
  # mullvad-vpn
  # google-drive
  # karabiner-elements

  # Fonts
  font-hack-nerd-font
)

# ── Bun Global Packages ──────────────────────────────────────────────────────
# Format: "package@version" — pinned for reproducibility
BUN_GLOBALS=(
  "typescript@5.9.3"
  "tsx@4.21.0"
  "vercel@50.9.5"
  # "@biomejs/biome@2.3.13"
  # "turbo@2.8.0"
  # "pyright@1.1.408"
)

# ── VS Code / Cursor Extensions ──────────────────────────────────────────────
# Install with: ./setup.sh --with-extensions
EXTENSIONS=(
  # Language support
  bradlc.vscode-tailwindcss
  esbenp.prettier-vscode
  ms-python.python
  rust-lang.rust-analyzer
  golang.go
  redhat.vscode-yaml

  # Git
  eamodio.gitlens
  donjayamanne.githistory

  # AI
  github.copilot
  github.copilot-chat

  # Utilities
  vscodevim.vim
  streetsidesoftware.code-spell-checker
  mechatroner.rainbow-csv
  emilast.logfilehighlighter

  # Docker / remote
  ms-azuretools.vscode-docker
  # ms-vscode-remote.remote-ssh
)

# ── macOS Defaults ────────────────────────────────────────────────────────────
# Set to "true" to apply each group, "false" to skip
APPLY_DOCK_DEFAULTS=true
APPLY_FINDER_DEFAULTS=true
APPLY_GLOBAL_DEFAULTS=true
APPLY_SCREENSHOT_DEFAULTS=true

# Dock settings (only if APPLY_DOCK_DEFAULTS=true)
DOCK_AUTOHIDE=true
DOCK_ORIENTATION="right"       # left, bottom, right
DOCK_TILESIZE=43
DOCK_MAGNIFICATION=true
DOCK_SHOW_RECENTS=false
DOCK_CLEAR_DEFAULT=true        # Remove all default dock items (Maps, Photos, etc.)
# DOCK_KEEP_APPS=()            # Override: list of .app paths to keep in dock
                                # If empty, auto-detects: Finder, Chrome, Warp/Terminal, Cursor

# ── Directories to create ────────────────────────────────────────────────────
DIRS=(
  "$HOME/projects"
  "$HOME/Documents/Screenshots"
)

# ── OpenClaw (optional) ──────────────────────────────────────────────────────
# Set to true to install OpenClaw + related tools
INSTALL_OPENCLAW=false

# OpenClaw-related bun globals (only if INSTALL_OPENCLAW=true)
OPENCLAW_GLOBALS=(
  "openclaw"
  "agent-browser@0.9.1"
  "mcporter@0.7.3"
  "clawhub"
)

# Non-interactive config: place your filled-in secrets files here
# (or set env vars OPENCLAW_SECRETS_JSON / OPENCLAW_SECRETS_ENV / OPENCLAW_SECRETS_AUTH)
#   cp config/openclaw-config.template.json openclaw-secrets.json
#   cp config/openclaw-env.template openclaw-secrets.env
#   cp config/openclaw-auth-profiles.template.json openclaw-auth-profiles.json
# The setup script auto-detects these in the repo root.

# ── Shell Setup ───────────────────────────────────────────────────────────────
# Set to true to install Prezto + Powerlevel10k
INSTALL_PREZTO=false
INSTALL_POWERLEVEL10K=false

# ── Rust ──────────────────────────────────────────────────────────────────────
INSTALL_RUST=false

# ── Additional scripts to run after setup ─────────────────────────────────────
# Add paths to scripts in this repo that should run after the main setup
POST_SCRIPTS=(
  "scripts/setup-zshrc.sh"
  # "scripts/import-keyboard-shortcuts.sh"
  # "scripts/install-arc-extensions.sh"
)
