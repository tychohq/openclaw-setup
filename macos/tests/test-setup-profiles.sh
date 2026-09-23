#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SETUP_SCRIPT="$ROOT_DIR/macos/setup.sh"
LAPTOP_BOOTSTRAP="$ROOT_DIR/macos/bootstrap-laptop.sh"
ORIGINAL_PATH="/usr/bin:/bin:/usr/sbin:/sbin"

pass() { printf 'PASS %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1" >&2; exit 1; }

assert_contains() {
  local file="$1" needle="$2" message="$3"
  grep -F "$needle" "$file" >/dev/null 2>&1 || fail "$message"
}

assert_not_contains() {
  local file="$1" needle="$2" message="$3"
  if grep -F "$needle" "$file" >/dev/null 2>&1; then fail "$message"; fi
}

assert_line_count() {
  local file="$1" pattern="$2" expected="$3" message="$4" actual
  actual="$(grep -Ec "$pattern" "$file" 2>/dev/null || true)"
  [[ "$actual" == "$expected" ]] || fail "$message (expected=$expected actual=$actual)"
}

assert_eq() {
  local actual="$1" expected="$2" message="$3"
  [[ "$actual" == "$expected" ]] || fail "$message (expected=$expected actual=$actual)"
}

make_stub() {
  local bin_dir="$1" name="$2"
  shift 2
  {
    printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail'
    printf '%s\n' "$@"
  } > "$bin_dir/$name"
  chmod +x "$bin_dir/$name"
}

create_stubs() {
  local bin_dir="$1"
  mkdir -p "$bin_dir"

  make_stub "$bin_dir" uname \
    'case "${1:-}" in -s) echo Darwin ;; -m) echo arm64 ;; *) echo Darwin ;; esac'
  make_stub "$bin_dir" xcode-select \
    'printf "xcode-select %s\n" "$*" >> "$MACOS_TEST_CALLS"' \
    '[[ "${1:-}" == "-p" ]] && { echo /Library/Developer/CommandLineTools; exit 0; }' \
    'exit 0'
  make_stub "$bin_dir" sudo \
    'printf "sudo %s\n" "$*" >> "$MACOS_TEST_CALLS"' \
    'exit 0'
  make_stub "$bin_dir" brew \
    'printf "brew %s\n" "$*" >> "$MACOS_TEST_CALLS"' \
    'case "$*" in' \
    '  shellenv) echo '\''export PATH="$HOME/homebrew/bin:$PATH"'\''; exit 0 ;;' \
    '  "tap") exit 0 ;;' \
    '  "list --formula --versions "*|"list --cask --versions "*) exit 1 ;;' \
    '  *) exit 0 ;;' \
    'esac'
  make_stub "$bin_dir" fnm \
    'printf "fnm %s\n" "$*" >> "$MACOS_TEST_CALLS"' \
    '[[ "${1:-}" == "env" ]] && echo '\''export PATH="$HOME/fnm-node/bin:$PATH"'\''' \
    '[[ "${1:-}" == "current" ]] && echo v24.0.0' \
    'exit 0'
  make_stub "$bin_dir" node 'echo v24.0.0'
  make_stub "$bin_dir" npm \
    'printf "npm %s\n" "$*" >> "$MACOS_TEST_CALLS"' \
    '[[ "${1:-}" == "list" || "${1:-}" == "ls" ]] && exit 1' \
    'exit 0'
  make_stub "$bin_dir" bun \
    'printf "bun %s\n" "$*" >> "$MACOS_TEST_CALLS"' \
    '[[ "${1:-}" == "--version" ]] && echo 1.2.0' \
    'exit 0'
  make_stub "$bin_dir" claude 'echo 1.0.0'
  make_stub "$bin_dir" git \
    'printf "git %s\n" "$*" >> "$MACOS_TEST_CALLS"' \
    'exit 0'
  make_stub "$bin_dir" defaults \
    'printf "defaults %s\n" "$*" >> "$MACOS_TEST_CALLS"' \
    'exit 0'
  make_stub "$bin_dir" pmset \
    'printf "pmset %s\n" "$*" >> "$MACOS_TEST_CALLS"' \
    'exit 0'
  make_stub "$bin_dir" systemsetup \
    'printf "systemsetup %s\n" "$*" >> "$MACOS_TEST_CALLS"' \
    'exit 0'
  make_stub "$bin_dir" launchctl \
    'printf "launchctl %s\n" "$*" >> "$MACOS_TEST_CALLS"' \
    'exit 0'
  make_stub "$bin_dir" killall \
    'printf "killall %s\n" "$*" >> "$MACOS_TEST_CALLS"' \
    'exit 0'
  make_stub "$bin_dir" ln \
    'printf "ln %s\n" "$*" >> "$MACOS_TEST_CALLS"' \
    'exit 0'
  make_stub "$bin_dir" curl \
    'printf "curl %s\n" "$*" >> "$MACOS_TEST_CALLS"' \
    'printf "#!/usr/bin/env bash\nexit 0\n"'
}

run_setup() {
  local scenario="$1"
  shift
  local base="$TEST_TMP/$scenario" home="$TEST_TMP/$scenario/home" bin="$TEST_TMP/$scenario/bin"
  mkdir -p "$home" "$bin"
  printf '# existing shell preference\n' > "$home/.zshrc"
  : > "$base/calls"
  create_stubs "$bin"
  if ! HOME="$home" MACOS_TEST_CALLS="$base/calls" MACOS_SETUP_BREW_BIN="$bin/brew" PATH="$bin:$ORIGINAL_PATH" \
    bash "$SETUP_SCRIPT" "$@" > "$base/output" 2>&1; then
    sed 's/^/  | /' "$base/output" >&2
    fail "$scenario setup execution failed"
  fi
}

test_laptop_default() {
  local base="$TEST_TMP/laptop-default" calls="$TEST_TMP/laptop-default/calls" output="$TEST_TMP/laptop-default/output"
  run_setup laptop-default --config "$ROOT_DIR/macos/config-laptop.sh"

  local expected
  for expected in google-chrome 1password raycast notion zoom spokenly chatgpt warp 1password-cli; do
    assert_contains "$calls" "brew install --cask $expected" "default laptop should install $expected"
  done
  assert_line_count "$calls" '^brew install --cask ' 9 "default laptop cask set should be exact"
  for expected in slack discord tailscale parsec visual-studio-code docker-desktop sublime-text font-hack-nerd-font codex-app; do
    assert_not_contains "$calls" "brew install --cask $expected" "default laptop should omit $expected"
  done
  for expected in fnm mas uv python; do
    assert_contains "$calls" "brew install $expected" "default laptop should install foundation formula $expected"
  done
  assert_contains "$calls" 'npm install -g @openai/codex@' "default laptop should install Codex CLI"
  assert_not_contains "$calls" 'npm install -g typescript@' "default laptop should omit technical npm tools"
  assert_contains "$output" 'Xcode CLT' "default laptop should include Xcode CLT foundation"
  assert_contains "$output" 'Homebrew' "default laptop should include Homebrew foundation"
  assert_contains "$output" 'Bun' "default laptop should include Bun foundation"
  assert_contains "$output" 'Node v24' "default laptop should include Node 24 foundation"
  assert_contains "$output" 'Claude Code' "default laptop should include Claude Code foundation"
  assert_contains "$output" 'laptop shell tool paths' "default laptop should install scoped shell integration"

  for expected in 'defaults ' 'pmset ' 'systemsetup ' 'launchctl ' 'killall ' 'git config' 'scripts/setup-zshrc.sh' 'openclaw' 'ln '; do
    assert_not_contains "$calls" "$expected" "laptop should not perform prohibited write: $expected"
  done

  assert_line_count "$base/home/.zshrc" '^# >>> openclaw laptop tool paths >>>$' 1 "laptop tool-path block should appear once"
  assert_contains "$base/home/.zshrc" '# existing shell preference' "laptop shell integration should preserve existing zsh configuration"
  assert_not_contains "$base/home/.zshrc" 'alias ' "laptop shell integration should not add aliases"

  mkdir -p "$base/home/homebrew/bin" "$base/home/fnm-node/bin" "$base/home/.bun/bin" "$base/home/.local/bin"
  for expected in brew fnm; do
    printf '#!/usr/bin/env bash\nexit 0\n' > "$base/home/homebrew/bin/$expected"
    chmod +x "$base/home/homebrew/bin/$expected"
  done
  cp "$base/bin/fnm" "$base/home/homebrew/bin/fnm"
  for expected in node npm codex; do
    printf '#!/usr/bin/env bash\nexit 0\n' > "$base/home/fnm-node/bin/$expected"
    chmod +x "$base/home/fnm-node/bin/$expected"
  done
  for expected in bun; do
    printf '#!/usr/bin/env bash\nexit 0\n' > "$base/home/.bun/bin/$expected"
    chmod +x "$base/home/.bun/bin/$expected"
  done
  for expected in claude; do
    printf '#!/usr/bin/env bash\nexit 0\n' > "$base/home/.local/bin/$expected"
    chmod +x "$base/home/.local/bin/$expected"
  done

  HOME="$base/home" MACOS_TEST_CALLS="$calls" PATH="$ORIGINAL_PATH" /bin/zsh -c '
    source "$HOME/.zshrc"
    for tool in brew fnm node npm codex bun claude; do command -v "$tool" >/dev/null || exit 1; done
  ' || fail "fresh zsh should expose Homebrew, fnm Node/npm/Codex, Bun, and ~/.local/bin tools"

  cp "$base/home/.zshrc" "$base/zshrc-before"
  HOME="$base/home" MACOS_TEST_CALLS="$calls" MACOS_SETUP_BREW_BIN="$base/bin/brew" \
    "$ROOT_DIR/macos/scripts/setup-laptop-tool-paths.sh"
  cmp -s "$base/zshrc-before" "$base/home/.zshrc" || fail "laptop shell integration should be byte-idempotent"

  : > "$calls"
  if HOME="$base/home" MACOS_TEST_CALLS="$calls" MACOS_SETUP_BREW_BIN="$base/bin/brew" PATH="$base/bin:$ORIGINAL_PATH" \
    bash "$SETUP_SCRIPT" --config "$ROOT_DIR/macos/config-laptop.sh" --handoff > "$base/handoff-output" 2>&1; then
    fail "laptop should reject handoff"
  fi
  assert_contains "$base/handoff-output" 'does not support --handoff' "laptop should explain rejected handoff"
  [[ ! -s "$calls" ]] || fail "rejected laptop handoff should exit before executing setup commands"
  pass "default laptop profile"
}

test_laptop_technical() {
  local calls="$TEST_TMP/laptop-technical/calls" expected
  run_setup laptop-technical --config "$ROOT_DIR/macos/config-laptop.sh" --technical

  for expected in visual-studio-code docker-desktop sublime-text font-hack-nerd-font; do
    assert_contains "$calls" "brew install --cask $expected" "technical laptop should install $expected"
  done
  for expected in fd ffmpeg fzf gh git-filter-repo htop imagemagick jq tmux wget; do
    assert_contains "$calls" "brew install $expected" "technical laptop should install $expected"
  done
  for expected in typescript tsx vercel; do
    assert_contains "$calls" "npm install -g $expected@" "technical laptop should install npm $expected"
  done
  for expected in 'defaults ' 'pmset ' 'systemsetup ' 'launchctl ' 'killall ' 'git config' 'openclaw'; do
    assert_not_contains "$calls" "$expected" "technical laptop should not perform prohibited write: $expected"
  done
  local default_symlinks technical_symlinks
  default_symlinks="$(TECHNICAL=false; source "$ROOT_DIR/macos/config-laptop.sh"; printf '%s' "$INSTALL_GUI_CLI_SYMLINKS")"
  technical_symlinks="$(TECHNICAL=true; source "$ROOT_DIR/macos/config-laptop.sh"; printf '%s' "$INSTALL_GUI_CLI_SYMLINKS")"
  assert_eq "$default_symlinks" "false" "default laptop should disable technical GUI symlinks"
  assert_eq "$technical_symlinks" "true" "technical laptop should enable GUI CLI symlinks"
  pass "technical laptop profile"
}

test_legacy_mini_profile() {
  local calls="$TEST_TMP/mini/calls" expected
  run_setup mini --config "$ROOT_DIR/macos/config.sh"

  for expected in google-chrome visual-studio-code docker-desktop sublime-text warp slack discord zoom 1password 1password-cli raycast notion chatgpt spokenly tailscale parsec font-hack-nerd-font; do
    assert_contains "$calls" "brew install --cask $expected" "Mini should retain $expected"
  done
  assert_line_count "$calls" '^brew install --cask ' 17 "Mini cask set should stay unchanged except ChatGPT correction"
  assert_not_contains "$calls" 'brew install --cask codex-app' "Mini should no longer use obsolete codex-app cask"
  assert_contains "$calls" 'sudo pmset -a sleep 0' "Mini should retain always-on power settings"
  assert_contains "$calls" 'sudo systemsetup -setremotelogin on' "Mini should retain remote login"
  assert_contains "$calls" 'git config --global init.defaultBranch main' "Mini should retain git defaults"
  assert_not_contains "$TEST_TMP/mini/home/.zshrc" '# >>> openclaw laptop tool paths >>>' "Mini should not receive laptop shell integration"
  pass "legacy Mini profile"
}

test_bootstrap_safe_modes() {
  local base="$TEST_TMP/bootstrap" bin="$TEST_TMP/bootstrap/bin" calls="$TEST_TMP/bootstrap/calls"
  mkdir -p "$base" "$bin"
  : > "$calls"
  for cmd in sudo xcode-select git curl; do
    make_stub "$bin" "$cmd" \
      'printf "%s %s\n" "$(basename "$0")" "$*" >> "$MACOS_TEST_CALLS"' \
      'exit 99'
  done

  HOME="$base/home" MACOS_TEST_CALLS="$calls" PATH="$bin:$ORIGINAL_PATH" \
    bash "$LAPTOP_BOOTSTRAP" --help > "$base/help" 2>&1
  [[ ! -s "$calls" ]] || fail "bootstrap --help should not invoke admin, CLT, git, or network commands"
  assert_contains "$base/help" 'OPENCLAW_SETUP_REF' "bootstrap help should document ref override"

  for rejected in --handoff --unknown --config; do
    : > "$calls"
    if HOME="$base/home" MACOS_TEST_CALLS="$calls" PATH="$bin:$ORIGINAL_PATH" \
      bash "$LAPTOP_BOOTSTRAP" "$rejected" > "$base/rejected" 2>&1; then
      fail "bootstrap should reject $rejected before admin work"
    fi
    [[ ! -s "$calls" ]] || fail "bootstrap rejection for $rejected should happen before admin, CLT, git, or network commands"
  done

  : > "$calls"
  OPENCLAW_SETUP_REPO_URL='https://example.invalid/fork.git' \
  OPENCLAW_SETUP_REF='0123456789abcdef0123456789abcdef01234567' \
  OPENCLAW_SETUP_CLONE_DIR="$base/checkout" \
  HOME="$base/home" MACOS_TEST_CALLS="$calls" PATH="$bin:$ORIGINAL_PATH" \
    bash "$LAPTOP_BOOTSTRAP" --dry-run --technical --with-extensions > "$base/dry-run" 2>&1
  [[ ! -s "$calls" ]] || fail "bootstrap --dry-run should not invoke admin, CLT, git, or network commands"
  assert_contains "$base/dry-run" 'https://example.invalid/fork.git' "dry-run should show selected repo"
  assert_contains "$base/dry-run" '0123456789abcdef0123456789abcdef01234567' "dry-run should show selected ref"
  assert_contains "$base/dry-run" 'Setup arguments: --dry-run --technical --with-extensions' "dry-run should show forwarded arguments"
  assert_contains "$LAPTOP_BOOTSTRAP" 'git -C "$CLONE_DIR" fetch --depth=1 origin "$REPO_REF"' "bootstrap should fetch the explicit ref"
  assert_contains "$LAPTOP_BOOTSTRAP" 'rev-parse --verify FETCH_HEAD^{commit}' "bootstrap should resolve the fetched ref to a commit"
  assert_contains "$LAPTOP_BOOTSTRAP" '"${SETUP_ARGS[@]}" --config "$RUN_DIR/macos/config-laptop.sh"' "bootstrap should forward arguments while forcing laptop config"
  pass "bootstrap safe help/dry-run and ref handling"
}

main() {
  TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/macos-profile-tests.XXXXXX")"
  trap 'rm -rf "$TEST_TMP"' EXIT
  test_laptop_default
  test_laptop_technical
  test_legacy_mini_profile
  test_bootstrap_safe_modes
}

main "$@"
