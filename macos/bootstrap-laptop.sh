#!/usr/bin/env bash
set -euo pipefail

# Laptop bootstrap entry point. Parse safe modes before platform, admin, CLT,
# filesystem, git, or network work so a piped script can always be inspected.

REPO_URL="${OPENCLAW_SETUP_REPO_URL:-https://github.com/tychohq/openclaw-setup.git}"
REPO_REF="${OPENCLAW_SETUP_REF:-main}"
CLONE_DIR="${OPENCLAW_SETUP_CLONE_DIR:-$HOME/projects/openclaw-setup-laptop}"
CURRENT_STEP="starting"
SUDO_KEEPALIVE_PID=""
RUN_DIR=""
SETUP_ARGS=("$@")

print_usage() {
  cat <<'EOF'
Usage: bootstrap-laptop.sh [OPTIONS]

Laptop options:
  --technical         Add developer GUI apps, utilities, and TS/tsx/Vercel tools
  --dry-run, -n       Preview the bootstrap without admin, CLT, git, or network writes
  --help, -h          Show this help

Other setup.sh options, such as --with-extensions, are forwarded unchanged.
The laptop profile rejects --handoff and never installs OpenClaw or Hermes.

Fetch controls:
  OPENCLAW_SETUP_REPO_URL   Git repository URL (default: tychohq/openclaw-setup)
  OPENCLAW_SETUP_REF        Branch, tag, or preferably full commit SHA (default: main)
  OPENCLAW_SETUP_CLONE_DIR  Local fetch cache (default: ~/projects/openclaw-setup-laptop)

The fetched ref is resolved to a commit and run from an isolated temporary
archive, so an existing checkout is never switched, reset, or overwritten.
EOF
}

DRY_RUN=false
SHOW_HELP=false
for arg in "$@"; do
  case "$arg" in
    --help|-h)
      SHOW_HELP=true
      ;;
    --dry-run|-n)
      DRY_RUN=true
      ;;
    --technical|--with-extensions|--skip-extensions|--extensions-only|--no-handoff)
      ;;
    --handoff)
      echo "The Mac Laptop profile does not support --handoff." >&2
      exit 1
      ;;
    --config)
      echo "bootstrap-laptop.sh always uses macos/config-laptop.sh; --config is not allowed." >&2
      exit 1
      ;;
    --*)
      echo "Unknown option: $arg" >&2
      print_usage >&2
      exit 1
      ;;
    *)
      echo "Unexpected argument: $arg" >&2
      print_usage >&2
      exit 1
      ;;
  esac
done

if [ "$SHOW_HELP" = true ]; then
  print_usage
  exit 0
fi

if [ "$DRY_RUN" = true ]; then
  echo "Mac Laptop Setup — Bootstrap Preview"
  echo ""
  echo "No admin check, CLT install, network request, clone, or setup change will run."
  echo "  Repository: $REPO_URL"
  echo "  Ref:        $REPO_REF"
  echo "  Cache:      $CLONE_DIR"
  printf '  Setup arguments:'
  printf ' %s' "${SETUP_ARGS[@]}"
  echo ""
  echo "  Profile:    macos/config-laptop.sh"
  echo ""
  echo "Default apps: google-chrome, 1password, raycast, notion, zoom, spokenly, chatgpt, warp, 1password-cli"
  echo "Laptop exclusions: Slack, Discord, remote-access apps, system defaults, OpenClaw, Hermes, and handoff"
  exit 0
fi

step() {
  CURRENT_STEP="$1"
  echo ""
  echo ">>> $1"
}

ok() { echo "  ✅ $1"; }
warn() { echo "  ⚠️  $1"; }
fail() { echo "❌ $1" >&2; }

cleanup() {
  if [ -n "$SUDO_KEEPALIVE_PID" ] && kill -0 "$SUDO_KEEPALIVE_PID" 2>/dev/null; then
    kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
  fi
  if [ -n "$RUN_DIR" ] && [ -d "$RUN_DIR" ]; then
    rm -rf "$RUN_DIR"
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
echo "║       Mac Laptop Setup — Bootstrap           ║"
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
if [ -n "${SETUP_PASSWORD:-}" ]; then
  if echo "$SETUP_PASSWORD" | sudo -S true 2>/dev/null; then
    ok "Admin access via SETUP_PASSWORD"
    export SETUP_PASSWORD
  else
    fail "SETUP_PASSWORD was set but sudo authentication failed."
    exit 1
  fi
elif sudo -n true 2>/dev/null; then
  ok "Admin access already available"
else
  if [ ! -r /dev/tty ]; then
    fail "Run this in Terminal so it can ask for your password, or set SETUP_PASSWORD."
    exit 1
  fi
  echo "  This setup needs your Mac password to install tools."
  sudo -v < /dev/tty
  ok "Password accepted"
fi

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
  echo "  A macOS pop-up may appear. Click Install, then return here."
  xcode-select --install 2>/dev/null || true
  until xcode-select -p &>/dev/null; do sleep 5; done
  ok "Apple Command Line Tools installed"
else
  ok "Apple Command Line Tools already installed"
fi

step "Fetching the requested setup revision"
mkdir -p "$(dirname "$CLONE_DIR")"

if [ -e "$CLONE_DIR" ] && [ ! -d "$CLONE_DIR/.git" ]; then
  fail "$CLONE_DIR exists but is not a git repository. Set OPENCLAW_SETUP_CLONE_DIR to another path."
  exit 1
fi

if [ ! -d "$CLONE_DIR/.git" ]; then
  mkdir -p "$CLONE_DIR"
  git -C "$CLONE_DIR" init -q
  git -C "$CLONE_DIR" remote add origin "$REPO_URL"
else
  EXISTING_URL="$(git -C "$CLONE_DIR" remote get-url origin 2>/dev/null || true)"
  if [ "$EXISTING_URL" != "$REPO_URL" ]; then
    fail "$CLONE_DIR uses origin '$EXISTING_URL', not '$REPO_URL'."
    fail "Set OPENCLAW_SETUP_CLONE_DIR to a separate path; the existing checkout was not changed."
    exit 1
  fi
fi

git -C "$CLONE_DIR" fetch --depth=1 origin "$REPO_REF"
RESOLVED_COMMIT="$(git -C "$CLONE_DIR" rev-parse --verify FETCH_HEAD^{commit})"
RUN_DIR="$(mktemp -d "${TMPDIR:-/tmp}/openclaw-laptop.XXXXXX")"
git -C "$CLONE_DIR" archive "$RESOLVED_COMMIT" | tar -x -C "$RUN_DIR"
ok "Resolved $REPO_REF to $RESOLVED_COMMIT"
ok "Existing checkout contents were not changed"

step "Starting the Mac laptop setup"
bash "$RUN_DIR/macos/setup.sh" "${SETUP_ARGS[@]}" --config "$RUN_DIR/macos/config-laptop.sh"
