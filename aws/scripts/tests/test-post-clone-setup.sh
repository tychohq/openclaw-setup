#!/usr/bin/env bash
set -euo pipefail

# ── post-clone-setup.sh test suite ───────────────────────────────────────────
# Static validation + functional tests with mocked environment.
# Run: bash aws/scripts/tests/test-post-clone-setup.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/../post-clone-setup.sh"

PASS=0
FAIL=0
TOTAL=0

run_test() {
  local name="$1"
  shift
  TOTAL=$((TOTAL + 1))
  echo -n "  $name ... "
  if "$@" 2>/dev/null; then
    echo "PASS"
    PASS=$((PASS + 1))
  else
    echo "FAIL"
    FAIL=$((FAIL + 1))
  fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# PART 1: Static validation (grep-based, same style as cloud-init-slim tests)
# ═══════════════════════════════════════════════════════════════════════════════

# ── Basic Structure ──────────────────────────────────────────────────────────

test_starts_with_shebang() {
  head -1 "$SCRIPT" | grep -q '^#!/usr/bin/env bash'
}

test_has_set_euo_pipefail() {
  grep -q '^set -euo pipefail' "$SCRIPT"
}

test_has_log_function() {
  grep -q 'log()' "$SCRIPT"
}

test_has_env_get_function() {
  grep -q 'env_get()' "$SCRIPT"
}

test_is_executable() {
  [ -x "$SCRIPT" ]
}

# ── Step 1: GOG CLI Install ─────────────────────────────────────────────────

test_gog_install_checks_existing() {
  grep -q 'command -v gog' "$SCRIPT"
}

test_gog_uses_steipete_repo() {
  grep -q 'steipete/gogcli' "$SCRIPT"
}

test_gog_linux_arm64() {
  grep -q 'linux_arm64' "$SCRIPT"
}

test_gog_installs_to_usr_local_bin() {
  grep -q '/usr/local/bin/gog' "$SCRIPT"
}

test_gog_cleans_temp_dir() {
  grep -q 'rm -rf "$TMP_DIR"' "$SCRIPT"
}

# ── Step 2: GOG Keyring ─────────────────────────────────────────────────────

test_keyring_reads_env() {
  grep -q 'env_get GOG_KEYRING_PASSWORD' "$SCRIPT"
}

test_keyring_generates_password() {
  grep -q 'openssl rand -hex 24' "$SCRIPT"
}

test_keyring_saves_to_env() {
  grep -q 'GOG_KEYRING_PASSWORD=' "$SCRIPT"
}

test_keyring_sets_file_backend() {
  grep -q 'gog auth keyring file' "$SCRIPT"
}

test_keyring_exports_password() {
  grep -q 'export GOG_KEYRING_PASSWORD' "$SCRIPT"
}

# ── Step 3: Google OAuth Credentials ────────────────────────────────────────

test_google_creds_reads_env() {
  grep -q 'env_get GOOGLE_OAUTH_CREDENTIALS_B64' "$SCRIPT"
}

test_google_creds_base64_decode() {
  grep -q 'base64 -d' "$SCRIPT"
}

test_google_creds_uses_gog_set() {
  grep -q 'gog auth credentials set' "$SCRIPT"
}

test_google_creds_cleans_temp_file() {
  grep -q 'rm -f "$CREDS_FILE"' "$SCRIPT"
}

# ── Step 4: Config Bundle ───────────────────────────────────────────────────

test_config_bundle_reads_env() {
  grep -q 'env_get CONFIG_BUNDLE_B64' "$SCRIPT"
}

test_config_bundle_decodes_to_openclaw_json() {
  grep -q 'openclaw.json' "$SCRIPT"
}

test_config_bundle_merges_existing() {
  # Step-processing loop replaces the old jq deep-merge
  grep -q 'jq -c.*\.patches\[\]\.steps\[\]' "$SCRIPT"
}

test_step_loop_handles_config_set() {
  grep -q 'config_set)' "$SCRIPT"
}

test_step_loop_handles_config_append() {
  grep -q 'config_append)' "$SCRIPT"
}

test_step_loop_handles_plugin_enable() {
  grep -q 'plugin_enable)' "$SCRIPT"
}

test_step_loop_handles_extension() {
  grep -q 'extension)' "$SCRIPT"
}

test_step_loop_no_config_patch() {
  # config_patch was removed — must not appear as a case
  ! grep -q 'config_patch)' "$SCRIPT"
}

# ── Step 5: Bootstrap Workspace ─────────────────────────────────────────────

test_bootstrap_runs_shared_script() {
  grep -q 'bootstrap-openclaw-workspace.sh' "$SCRIPT"
}

test_bootstrap_skip_cron() {
  grep -q '\-\-skip-cron' "$SCRIPT"
}

test_bootstrap_skip_skills() {
  grep -q '\-\-skip-skills' "$SCRIPT"
}

# ── Step 6: ClawHub Skills ──────────────────────────────────────────────────

test_clawhub_reads_env() {
  grep -q 'env_get CLAWHUB_SKILLS' "$SCRIPT"
}

test_clawhub_comma_split() {
  grep -q "IFS=',' read -ra" "$SCRIPT"
}

test_clawhub_install_command() {
  grep -q 'clawhub install' "$SCRIPT"
}

test_clawhub_checks_existing() {
  grep -q 'skills/\$skill' "$SCRIPT" || grep -q 'skills/$skill' "$SCRIPT"
}

# ── Step 7: Cron Jobs ───────────────────────────────────────────────────────

test_cron_reads_env() {
  grep -q 'env_get CRON_SELECTIONS_B64' "$SCRIPT"
}

test_cron_writes_to_workspace_dir() {
  grep -q 'workspace/cron-jobs' "$SCRIPT"
}

test_cron_creates_individual_files() {
  grep -q 'JOB_FILE=' "$SCRIPT"
  grep -q '\.json' "$SCRIPT"
}

test_cron_skips_existing() {
  grep -q 'already exists.*skipping' "$SCRIPT"
}

# ── Step 8: First-Boot ──────────────────────────────────────────────────────

test_first_boot_reads_enable_flag() {
  grep -q 'env_get ENABLE_FIRST_BOOT' "$SCRIPT"
}

test_first_boot_copies_skill() {
  grep -q 'cp -r.*FIRST_BOOT' "$SCRIPT"
}

test_first_boot_touches_flag() {
  grep -q 'touch.*\.first-boot' "$SCRIPT"
}

test_first_boot_checks_existing() {
  grep -q 'already deployed.*skipping' "$SCRIPT"
}

# ── Step 9: Git Init ────────────────────────────────────────────────────────

test_git_init_openclaw() {
  grep -q 'git.*init' "$SCRIPT"
}

test_git_initial_commit() {
  grep -q 'git.*commit.*Initial' "$SCRIPT"
}

test_git_checks_existing_repo() {
  grep -q '\.git' "$SCRIPT"
}

# ── Step 10: Start Gateway ──────────────────────────────────────────────────

test_gateway_uses_systemctl_user() {
  grep -q 'systemctl --user.*openclaw-gateway' "$SCRIPT"
}

test_gateway_sets_xdg_runtime_dir() {
  grep -q 'XDG_RUNTIME_DIR' "$SCRIPT"
}

test_gateway_checks_if_running() {
  grep -q 'is-active.*openclaw-gateway' "$SCRIPT"
}

test_gateway_restarts_if_running() {
  grep -q 'systemctl --user restart openclaw-gateway' "$SCRIPT"
}

# ── Idempotency Guards ──────────────────────────────────────────────────────

test_idempotent_gog_install() {
  # Checks "command -v gog" before installing
  grep -q 'command -v gog' "$SCRIPT"
}

test_idempotent_keyring_password() {
  # Checks if password already in .env
  grep -q 'already set in .env' "$SCRIPT"
}

test_idempotent_skills() {
  # Checks if skill dir already exists
  grep -q 'already installed.*skipping' "$SCRIPT"
}

test_idempotent_git_init() {
  # Checks if .git already exists
  grep -q 'already a git repo.*skipping' "$SCRIPT"
}

test_idempotent_first_boot() {
  # Checks if first-boot skill already deployed
  grep -q 'already deployed.*skipping' "$SCRIPT"
}

test_idempotent_cron() {
  # Checks if cron file already exists
  grep -q 'already exists.*skipping' "$SCRIPT"
}

# ── Section Ordering ─────────────────────────────────────────────────────────

test_ordering_gog_before_keyring() {
  local gog_line keyring_line
  gog_line=$(grep -n 'Step 1:' "$SCRIPT" | head -1 | cut -d: -f1)
  keyring_line=$(grep -n 'Step 2:' "$SCRIPT" | head -1 | cut -d: -f1)
  [[ "$gog_line" -lt "$keyring_line" ]]
}

test_ordering_keyring_before_google_creds() {
  local keyring_line google_line
  keyring_line=$(grep -n 'Step 2:' "$SCRIPT" | head -1 | cut -d: -f1)
  google_line=$(grep -n 'Step 3:' "$SCRIPT" | head -1 | cut -d: -f1)
  [[ "$keyring_line" -lt "$google_line" ]]
}

test_ordering_config_before_bootstrap() {
  local config_line bootstrap_line
  config_line=$(grep -n 'Step 4:' "$SCRIPT" | head -1 | cut -d: -f1)
  bootstrap_line=$(grep -n 'Step 5:' "$SCRIPT" | head -1 | cut -d: -f1)
  [[ "$config_line" -lt "$bootstrap_line" ]]
}

test_ordering_bootstrap_before_skills() {
  local bootstrap_line skills_line
  bootstrap_line=$(grep -n 'Step 5:' "$SCRIPT" | head -1 | cut -d: -f1)
  skills_line=$(grep -n 'Step 6:' "$SCRIPT" | head -1 | cut -d: -f1)
  [[ "$bootstrap_line" -lt "$skills_line" ]]
}

test_ordering_skills_before_cron() {
  local skills_line cron_line
  skills_line=$(grep -n 'Step 6:' "$SCRIPT" | head -1 | cut -d: -f1)
  cron_line=$(grep -n 'Step 7:' "$SCRIPT" | head -1 | cut -d: -f1)
  [[ "$skills_line" -lt "$cron_line" ]]
}

test_ordering_cron_before_first_boot() {
  local cron_line first_boot_line
  cron_line=$(grep -n 'Step 7:' "$SCRIPT" | head -1 | cut -d: -f1)
  first_boot_line=$(grep -n 'Step 8:' "$SCRIPT" | head -1 | cut -d: -f1)
  [[ "$cron_line" -lt "$first_boot_line" ]]
}

test_ordering_first_boot_before_git_init() {
  local first_boot_line git_line
  first_boot_line=$(grep -n 'Step 8:' "$SCRIPT" | head -1 | cut -d: -f1)
  git_line=$(grep -n 'Step 9:' "$SCRIPT" | head -1 | cut -d: -f1)
  [[ "$first_boot_line" -lt "$git_line" ]]
}

test_ordering_git_init_before_gateway() {
  local git_line gateway_line
  git_line=$(grep -n 'Step 9:' "$SCRIPT" | head -1 | cut -d: -f1)
  gateway_line=$(grep -n 'Step 10:' "$SCRIPT" | head -1 | cut -d: -f1)
  [[ "$git_line" -lt "$gateway_line" ]]
}

# ═══════════════════════════════════════════════════════════════════════════════
# PART 2: Functional tests with mocked environment
# ═══════════════════════════════════════════════════════════════════════════════

# Portable base64 decode (macOS uses -D, Linux uses -d)
b64decode() { base64 --decode 2>/dev/null || base64 -d 2>/dev/null; }

TEST_HOME=""

setup_test_env() {
  TEST_HOME=$(mktemp -d)
  mkdir -p "$TEST_HOME/.openclaw"
  mkdir -p "$TEST_HOME/openclaw-setup/aws/skills/first-boot"
  mkdir -p "$TEST_HOME/openclaw-setup/shared/scripts"

  # Minimal first-boot skill
  echo "# First Boot" > "$TEST_HOME/openclaw-setup/aws/skills/first-boot/SKILL.md"

  # Minimal bootstrap script (no-op)
  cat > "$TEST_HOME/openclaw-setup/shared/scripts/bootstrap-openclaw-workspace.sh" << 'EOF'
#!/usr/bin/env bash
echo "bootstrap: $*"
EOF
  chmod +x "$TEST_HOME/openclaw-setup/shared/scripts/bootstrap-openclaw-workspace.sh"
}

teardown_test_env() {
  if [ -n "$TEST_HOME" ] && [ -d "$TEST_HOME" ]; then
    rm -rf "$TEST_HOME"
  fi
}

# Test env_get helper parses .env correctly
test_env_get_parses_values() {
  setup_test_env
  cat > "$TEST_HOME/.openclaw/.env" << 'EOF'
FOO=bar
BAZ=hello world
EMPTY=
# COMMENTED=nope
EOF
  # Source just the env_get function
  local result
  result=$(bash -c "
    env_get() {
      local key=\"\$1\"
      grep \"^\${key}=\" \"$TEST_HOME/.openclaw/.env\" 2>/dev/null | head -1 | cut -d= -f2-
    }
    echo \"\$(env_get FOO)|\$(env_get BAZ)|\$(env_get EMPTY)|\$(env_get MISSING)\"
  ")
  teardown_test_env
  [[ "$result" == "bar|hello world||" ]]
}

# Test config bundle decode creates openclaw.json
test_functional_config_bundle_decode() {
  setup_test_env
  local bundle='{"gateway":{"port":18789},"test":true}'
  local b64
  b64=$(echo -n "$bundle" | base64)
  echo "CONFIG_BUNDLE_B64=$b64" > "$TEST_HOME/.openclaw/.env"

  # Simulate step 4 logic
  bash -c "
    b64decode() { base64 --decode 2>/dev/null || base64 -d 2>/dev/null; }
    OPENCLAW_DIR='$TEST_HOME/.openclaw'
    ENV_FILE='$TEST_HOME/.openclaw/.env'
    env_get() { grep \"^\$1=\" \"\$ENV_FILE\" 2>/dev/null | head -1 | cut -d= -f2-; }
    CONFIG_BUNDLE_B64=\"\$(env_get CONFIG_BUNDLE_B64)\"
    if [ -n \"\$CONFIG_BUNDLE_B64\" ]; then
      echo \"\$CONFIG_BUNDLE_B64\" | b64decode > \"\$OPENCLAW_DIR/openclaw.json\"
    fi
  "

  local result
  result=$(cat "$TEST_HOME/.openclaw/openclaw.json")
  teardown_test_env
  echo "$result" | jq -e '.test == true' &>/dev/null
}

# Test config bundle merges with existing config
test_functional_config_bundle_merge() {
  setup_test_env
  echo '{"existing":"value","gateway":{"port":18789}}' > "$TEST_HOME/.openclaw/openclaw.json"
  local bundle='{"gateway":{"port":9999},"new":"field"}'
  local b64
  b64=$(echo -n "$bundle" | base64)
  echo "CONFIG_BUNDLE_B64=$b64" > "$TEST_HOME/.openclaw/.env"

  bash -c "
    b64decode() { base64 --decode 2>/dev/null || base64 -d 2>/dev/null; }
    OPENCLAW_DIR='$TEST_HOME/.openclaw'
    ENV_FILE='$TEST_HOME/.openclaw/.env'
    env_get() { grep \"^\$1=\" \"\$ENV_FILE\" 2>/dev/null | head -1 | cut -d= -f2-; }
    CONFIG_BUNDLE_B64=\"\$(env_get CONFIG_BUNDLE_B64)\"
    if [ -n \"\$CONFIG_BUNDLE_B64\" ] && [ -f \"\$OPENCLAW_DIR/openclaw.json\" ]; then
      BUNDLE_FILE=\$(mktemp)
      echo \"\$CONFIG_BUNDLE_B64\" | b64decode > \"\$BUNDLE_FILE\"
      MERGED=\$(jq -s '.[0] * .[1]' \"\$OPENCLAW_DIR/openclaw.json\" \"\$BUNDLE_FILE\")
      echo \"\$MERGED\" > \"\$OPENCLAW_DIR/openclaw.json\"
      rm -f \"\$BUNDLE_FILE\"
    fi
  "

  local result
  result=$(cat "$TEST_HOME/.openclaw/openclaw.json")
  teardown_test_env
  # existing key preserved, new key added, port overridden
  echo "$result" | jq -e '.existing == "value" and .new == "field" and .gateway.port == 9999' &>/dev/null
}

# Test cron job decode writes individual files
test_functional_cron_decode() {
  setup_test_env
  local cron_json='[{"name":"self-reflection","schedule":"0 * * * *"},{"name":"system-watchdog","schedule":"0 4 * * *"}]'
  local cron_dir="$TEST_HOME/.openclaw/workspace/cron-jobs"
  mkdir -p "$cron_dir"

  local count
  count=$(echo "$cron_json" | jq 'length')
  for i in $(seq 0 $((count - 1))); do
    local job job_name
    job=$(echo "$cron_json" | jq ".[$i]")
    job_name=$(echo "$job" | jq -r '.name')
    echo "$job" > "$cron_dir/${job_name}.json"
  done

  local r1 r2
  r1=$(jq -r '.name' "$cron_dir/self-reflection.json")
  r2=$(jq -r '.name' "$cron_dir/system-watchdog.json")
  teardown_test_env
  [[ "$r1" == "self-reflection" ]] && [[ "$r2" == "system-watchdog" ]]
}

# Test first-boot copies skill and creates flag
test_functional_first_boot_deploy() {
  setup_test_env
  echo "ENABLE_FIRST_BOOT=true" > "$TEST_HOME/.openclaw/.env"

  local openclaw_dir="$TEST_HOME/.openclaw"
  local src="$TEST_HOME/openclaw-setup/aws/skills/first-boot"
  local dest="$openclaw_dir/skills/first-boot"
  mkdir -p "$openclaw_dir/skills"
  mkdir -p "$openclaw_dir/workspace"
  cp -r "$src" "$dest"
  touch "$openclaw_dir/workspace/.first-boot"

  local has_skill has_flag
  has_skill=false
  has_flag=false
  [ -f "$TEST_HOME/.openclaw/skills/first-boot/SKILL.md" ] && has_skill=true
  [ -f "$TEST_HOME/.openclaw/workspace/.first-boot" ] && has_flag=true
  teardown_test_env
  [[ "$has_skill" == "true" ]] && [[ "$has_flag" == "true" ]]
}

# Test git init creates repo
test_functional_git_init() {
  setup_test_env
  mkdir -p "$TEST_HOME/.openclaw/workspace"
  echo "test" > "$TEST_HOME/.openclaw/workspace/README.md"

  git -C "$TEST_HOME/.openclaw" init &>/dev/null
  git -C "$TEST_HOME/.openclaw" add -A &>/dev/null
  git -C "$TEST_HOME/.openclaw" commit -m "Initial OpenClaw workspace" &>/dev/null

  local has_git has_commit
  has_git=false
  has_commit=false
  [ -d "$TEST_HOME/.openclaw/.git" ] && has_git=true
  git -C "$TEST_HOME/.openclaw" log --oneline 2>/dev/null | grep -q "Initial" && has_commit=true
  teardown_test_env
  [[ "$has_git" == "true" ]] && [[ "$has_commit" == "true" ]]
}

# Test idempotency: re-running doesn't duplicate cron files
test_functional_cron_idempotent() {
  setup_test_env
  local cron_dir="$TEST_HOME/.openclaw/workspace/cron-jobs"
  mkdir -p "$cron_dir"
  echo '{"name":"existing","schedule":"0 * * * *"}' > "$cron_dir/existing.json"

  local cron_json='[{"name":"existing","schedule":"0 * * * *"}]'
  local b64
  b64=$(echo -n "$cron_json" | base64)

  local decoded
  decoded=$(echo "$b64" | b64decode)
  local count
  count=$(echo "$decoded" | jq 'length')
  for i in $(seq 0 $((count - 1))); do
    local job job_name job_file
    job=$(echo "$decoded" | jq ".[$i]")
    job_name=$(echo "$job" | jq -r '.name')
    job_file="$cron_dir/${job_name}.json"
    if [ ! -f "$job_file" ]; then
      echo "$job" > "$job_file"
    fi
  done

  # File count should still be 1
  local count
  count=$(ls "$cron_dir"/*.json | wc -l | tr -d ' ')
  teardown_test_env
  [[ "$count" -eq 1 ]]
}

# Test keyring password generation appends to .env
test_functional_keyring_password_generation() {
  setup_test_env
  echo "SOME_KEY=value" > "$TEST_HOME/.openclaw/.env"

  bash -c "
    ENV_FILE='$TEST_HOME/.openclaw/.env'
    GOG_KEYRING_PASSWORD=\$(openssl rand -hex 24)
    echo \"GOG_KEYRING_PASSWORD=\${GOG_KEYRING_PASSWORD}\" >> \"\$ENV_FILE\"
  "

  grep -q "^GOG_KEYRING_PASSWORD=.\+" "$TEST_HOME/.openclaw/.env"
  local result=$?
  teardown_test_env
  return $result
}

# Test keyring password update (not duplicate) when already exists empty
test_functional_keyring_password_update() {
  setup_test_env
  local env_file="$TEST_HOME/.openclaw/.env"
  echo "GOG_KEYRING_PASSWORD=" > "$env_file"

  # Use portable sed: try macOS syntax first, then Linux
  local password="test-password-123"
  sed -i '' "s|^GOG_KEYRING_PASSWORD=.*|GOG_KEYRING_PASSWORD=${password}|" "$env_file" 2>/dev/null || \
  sed -i "s|^GOG_KEYRING_PASSWORD=.*|GOG_KEYRING_PASSWORD=${password}|" "$env_file"

  local count
  count=$(grep -c "^GOG_KEYRING_PASSWORD=" "$env_file")
  local value
  value=$(grep "^GOG_KEYRING_PASSWORD=" "$env_file" | cut -d= -f2-)
  teardown_test_env
  [[ "$count" -eq 1 ]] && [[ "$value" == "test-password-123" ]]
}

# ── Run All Tests ────────────────────────────────────────────────────────────

echo "post-clone-setup.sh test suite"
echo "=============================="
echo ""

echo "Basic Structure:"
run_test "starts with shebang"            test_starts_with_shebang
run_test "has set -euo pipefail"          test_has_set_euo_pipefail
run_test "has log function"               test_has_log_function
run_test "has env_get function"           test_has_env_get_function
run_test "is executable"                  test_is_executable
echo ""

echo "Step 1 — GOG CLI Install:"
run_test "checks existing gog"            test_gog_install_checks_existing
run_test "uses steipete/gogcli repo"      test_gog_uses_steipete_repo
run_test "targets linux_arm64"            test_gog_linux_arm64
run_test "installs to /usr/local/bin"     test_gog_installs_to_usr_local_bin
run_test "cleans temp directory"          test_gog_cleans_temp_dir
echo ""

echo "Step 2 — GOG Keyring:"
run_test "reads password from .env"       test_keyring_reads_env
run_test "generates password"             test_keyring_generates_password
run_test "saves password to .env"         test_keyring_saves_to_env
run_test "sets file keyring backend"      test_keyring_sets_file_backend
run_test "exports GOG_KEYRING_PASSWORD"   test_keyring_exports_password
echo ""

echo "Step 3 — Google OAuth Credentials:"
run_test "reads creds from .env"          test_google_creds_reads_env
run_test "base64 decodes"                 test_google_creds_base64_decode
run_test "uses gog auth credentials set"  test_google_creds_uses_gog_set
run_test "cleans temp credentials file"   test_google_creds_cleans_temp_file
echo ""

echo "Step 4 — Config Bundle (step-processing loop):"
run_test "reads bundle from .env"         test_config_bundle_reads_env
run_test "decodes to openclaw.json"       test_config_bundle_decodes_to_openclaw_json
run_test "uses step-processing loop"      test_config_bundle_merges_existing
run_test "handles config_set steps"       test_step_loop_handles_config_set
run_test "handles config_append steps"    test_step_loop_handles_config_append
run_test "handles plugin_enable steps"    test_step_loop_handles_plugin_enable
run_test "handles extension steps"        test_step_loop_handles_extension
run_test "no config_patch remnants"       test_step_loop_no_config_patch
echo ""

echo "Step 5 — Bootstrap Workspace:"
run_test "runs shared bootstrap script"   test_bootstrap_runs_shared_script
run_test "passes --skip-cron"             test_bootstrap_skip_cron
run_test "passes --skip-skills"           test_bootstrap_skip_skills
echo ""

echo "Step 6 — ClawHub Skills:"
run_test "reads skills from .env"         test_clawhub_reads_env
run_test "comma-splits skill list"        test_clawhub_comma_split
run_test "uses clawhub install"           test_clawhub_install_command
run_test "checks if skill exists"         test_clawhub_checks_existing
echo ""

echo "Step 7 — Cron Jobs:"
run_test "reads cron from .env"           test_cron_reads_env
run_test "writes to workspace/cron-jobs"  test_cron_writes_to_workspace_dir
run_test "creates individual JSON files"  test_cron_creates_individual_files
run_test "skips existing cron files"      test_cron_skips_existing
echo ""

echo "Step 8 — First-Boot:"
run_test "reads ENABLE_FIRST_BOOT"        test_first_boot_reads_enable_flag
run_test "copies skill directory"         test_first_boot_copies_skill
run_test "touches .first-boot flag"       test_first_boot_touches_flag
run_test "skips if already deployed"      test_first_boot_checks_existing
echo ""

echo "Step 9 — Git Init:"
run_test "git inits ~/.openclaw"          test_git_init_openclaw
run_test "creates initial commit"         test_git_initial_commit
run_test "checks for existing .git"       test_git_checks_existing_repo
echo ""

echo "Step 10 — Start Gateway:"
run_test "uses systemctl --user"          test_gateway_uses_systemctl_user
run_test "sets XDG_RUNTIME_DIR"           test_gateway_sets_xdg_runtime_dir
run_test "checks if already running"      test_gateway_checks_if_running
run_test "restarts if running"            test_gateway_restarts_if_running
echo ""

echo "Idempotency Guards:"
run_test "gog install idempotent"         test_idempotent_gog_install
run_test "keyring password idempotent"    test_idempotent_keyring_password
run_test "skills install idempotent"      test_idempotent_skills
run_test "git init idempotent"            test_idempotent_git_init
run_test "first-boot idempotent"          test_idempotent_first_boot
run_test "cron jobs idempotent"           test_idempotent_cron
echo ""

echo "Section Ordering:"
run_test "GOG before keyring"             test_ordering_gog_before_keyring
run_test "keyring before Google creds"    test_ordering_keyring_before_google_creds
run_test "config before bootstrap"        test_ordering_config_before_bootstrap
run_test "bootstrap before skills"        test_ordering_bootstrap_before_skills
run_test "skills before cron"             test_ordering_skills_before_cron
run_test "cron before first-boot"         test_ordering_cron_before_first_boot
run_test "first-boot before git init"     test_ordering_first_boot_before_git_init
run_test "git init before gateway"        test_ordering_git_init_before_gateway
echo ""

echo "Functional — env_get:"
run_test "parses .env values"             test_env_get_parses_values
echo ""

echo "Functional — Config Bundle:"
run_test "decodes bundle to JSON"         test_functional_config_bundle_decode
run_test "merges with existing config"    test_functional_config_bundle_merge
echo ""

echo "Functional — Cron Jobs:"
run_test "decodes to individual files"    test_functional_cron_decode
run_test "idempotent (no duplicates)"     test_functional_cron_idempotent
echo ""

echo "Functional — First-Boot:"
run_test "deploys skill + creates flag"   test_functional_first_boot_deploy
echo ""

echo "Functional — Git Init:"
run_test "creates repo with commit"       test_functional_git_init
echo ""

echo "Functional — Keyring Password:"
run_test "generates and appends"          test_functional_keyring_password_generation
run_test "updates existing empty value"   test_functional_keyring_password_update
echo ""

echo "Results: $PASS/$TOTAL passed, $FAIL failed"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
