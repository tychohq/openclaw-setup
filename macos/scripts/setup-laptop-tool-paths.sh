#!/usr/bin/env bash
set -euo pipefail

# Add only the tool initialization required by the laptop profile. This does
# not install aliases, prompts, themes, or other personal shell preferences.

ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"
BEGIN_MARKER="# >>> openclaw laptop tool paths >>>"
END_MARKER="# <<< openclaw laptop tool paths <<<"

BREW_BIN="${MACOS_SETUP_BREW_BIN:-}"
if [ -z "$BREW_BIN" ]; then
  if [ -x /opt/homebrew/bin/brew ]; then
    BREW_BIN="/opt/homebrew/bin/brew"
  elif [ -x /usr/local/bin/brew ]; then
    BREW_BIN="/usr/local/bin/brew"
  elif command -v brew >/dev/null 2>&1; then
    BREW_BIN="$(command -v brew)"
  else
    echo "Homebrew executable not found; cannot configure laptop tool paths." >&2
    exit 1
  fi
fi

mkdir -p "$(dirname "$ZSHRC")"
touch "$ZSHRC"

candidate="$(mktemp "${TMPDIR:-/tmp}/openclaw-laptop-zshrc.XXXXXX")"
cleanup() { rm -f "$candidate"; }
trap cleanup EXIT

awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
  $0 == begin { skipping = 1; next }
  skipping && $0 == end { skipping = 0; next }
  !skipping { print }
' "$ZSHRC" > "$candidate"

# Keep a single blank line before the managed block when the file has content.
if [ -s "$candidate" ] && [ -n "$(tail -n 1 "$candidate")" ]; then
  printf '\n' >> "$candidate"
fi

cat >> "$candidate" <<EOF
$BEGIN_MARKER
if [ -x "$BREW_BIN" ]; then
  eval "\$("$BREW_BIN" shellenv)"
fi

export BUN_INSTALL="\$HOME/.bun"
export PATH="\$HOME/.local/bin:\$BUN_INSTALL/bin:\$PATH"

if command -v fnm >/dev/null 2>&1; then
  eval "\$(fnm env --use-on-cd --version-file-strategy=recursive --shell zsh)"
fi
$END_MARKER
EOF

if cmp -s "$candidate" "$ZSHRC"; then
  exit 0
fi

cp "$candidate" "$ZSHRC"
