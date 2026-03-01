#!/usr/bin/env bash
# =============================================================================
# setup-zshrc.sh — Add useful shell aliases and functions to ~/.zshrc
#
# Idempotent — checks for a marker comment before appending.
# Only adds generally-useful stuff. Personal/project-specific aliases
# should go in your own dotfiles.
# =============================================================================
set -euo pipefail

ZSHRC="$HOME/.zshrc"
MARKER="# ── mac-mini-setup shell additions ──"

if grep -qF "$MARKER" "$ZSHRC" 2>/dev/null; then
  echo "  ⏭️  Shell additions already in ~/.zshrc (found marker)"
  exit 0
fi

# Create .zshrc if it doesn't exist
touch "$ZSHRC"

cat >> "$ZSHRC" << 'SHELL_ADDITIONS'

# ── mac-mini-setup shell additions ──────────────────────────────────────────

# ── Navigation ────────────────────────────────────────────────────────────────
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
mkcd() { mkdir -p "$1" && cd "$1"; }

# ── Git shortcuts ─────────────────────────────────────────────────────────────
alias gs="git status"
alias ga="git add"
alias gb="git branch"
alias gc="git commit"
alias gd="git diff"
alias gco="git checkout"
alias gcm="git commit -m"
alias gf="git fetch"
alias gpf='git push -f'
alias glo='git log --oneline'
alias gpl='git pull'
alias gplr='git pull --rebase'
alias gst='git stash'
alias gstp='git stash pop'
alias glg='git log --graph --oneline --decorate'

gcob() { git checkout -b "$1" && git push -u origin "$1"; }
gbdel() { for b in "$@"; do git branch -D "$b"; git push origin :"$b"; done; }
grap() { git fetch && git rebase 'origin/main' && git push -f; }
squash() { git rebase -i "HEAD~$1"; }

# ── Editor shortcuts ──────────────────────────────────────────────────────────
alias ss='subl ./'
zedit() { ${EDITOR:-code} --wait ~/.zshrc && source ~/.zshrc; }

# ── AI coding agents ─────────────────────────────────────────────────────────
alias cc='claude --dangerously-skip-permissions'
alias cx='codex --dangerously-bypass-approvals-and-sandbox'

# Claude Code in a tmux session (named after current dir)
claumux() {
  local session_name="${PWD##*/}-claude"
  if tmux has-session -t "$session_name" 2>/dev/null; then
    tmux attach-session -t "$session_name"
  else
    tmux new-session -s "$session_name" "claude --dangerously-skip-permissions"
  fi
}

# Codex in a tmux session
comux() {
  local session_name="${PWD##*/}-codex"
  if tmux has-session -t "$session_name" 2>/dev/null; then
    tmux attach-session -t "$session_name"
  else
    tmux new-session -s "$session_name" "codex --dangerously-bypass-approvals-and-sandbox"
  fi
}

# ── Dev shortcuts ─────────────────────────────────────────────────────────────
alias python=python3
alias pip=pip3

# ── Utilities ─────────────────────────────────────────────────────────────────
alias alert='afplay /System/Library/Sounds/Glass.aiff; terminal-notifier -title "Terminal" -message "Done with task!"'

# ── PATH additions ────────────────────────────────────────────────────────────
typeset -U PATH
export BUN_INSTALL="$HOME/.bun"
path=(
  "$BUN_INSTALL/bin"
  "$HOME/.local/bin"
  "/usr/local/bin"
  $path
)

# ── Tool integrations (loaded if available) ───────────────────────────────────
# fnm (fast node manager)
command -v fnm &>/dev/null && eval "$(fnm env --use-on-cd --version-file-strategy=recursive --shell zsh)"

# fzf (fuzzy finder)
command -v fzf &>/dev/null && source <(fzf --zsh)

# Bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# OpenClaw completions
[ -s "$HOME/.openclaw/completions/openclaw.zsh" ] && source "$HOME/.openclaw/completions/openclaw.zsh"

# ── end mac-mini-setup ──────────────────────────────────────────────────────
SHELL_ADDITIONS

echo "  ✅ Shell additions appended to ~/.zshrc"
echo "     Run: source ~/.zshrc"
