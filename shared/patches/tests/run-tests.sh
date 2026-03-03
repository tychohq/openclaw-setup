#!/usr/bin/env bash
set -euo pipefail

# ── openclaw-patch test suite ────────────────────────────────────────────────
# Exercises each step type, idempotency, target filtering, and ordering.
# Uses temp dirs so nothing touches real ~/.openclaw.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI="$SCRIPT_DIR/../scripts/openclaw-patch"
FIXTURES="$SCRIPT_DIR/fixtures"

PASS=0
FAIL=0
TOTAL=0

# ── Helpers ──────────────────────────────────────────────────────────────────

setup() {
  TEST_HOME="$(mktemp -d)"
  TEST_PATCHES="$(mktemp -d)"
  MOCK_BIN="$(mktemp -d)"

  # Copy fixture files/skills/extensions into the test patches dir
  mkdir -p "$TEST_PATCHES/patches" "$TEST_PATCHES/files" "$TEST_PATCHES/skills" "$TEST_PATCHES/extensions"
  cp -r "$FIXTURES/files/"* "$TEST_PATCHES/files/" 2>/dev/null || true
  cp -r "$FIXTURES/skills/"* "$TEST_PATCHES/skills/" 2>/dev/null || true
  cp -r "$FIXTURES/extensions/"* "$TEST_PATCHES/extensions/" 2>/dev/null || true

  export OPENCLAW_HOME="$TEST_HOME"
  export OPENCLAW_PATCHES_DIR="$TEST_PATCHES"
}

# Create a mock openclaw binary that logs calls to a file
setup_mock_openclaw() {
  cat > "$MOCK_BIN/openclaw" << 'MOCK'
#!/usr/bin/env bash
echo "$@" >> "${OPENCLAW_HOME}/mock-openclaw-calls.txt"
# For cron list --json, return empty array
if [[ "$1" == "cron" && "$2" == "list" && "$*" == *"--json"* ]]; then
  echo "[]"
fi
MOCK
  chmod +x "$MOCK_BIN/openclaw"
  export PATH="$MOCK_BIN:$PATH"
}

teardown() {
  rm -rf "$TEST_HOME" "$TEST_PATCHES" "$MOCK_BIN"
  unset OPENCLAW_HOME OPENCLAW_PATCHES_DIR
}

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

# Copy a single fixture patch into the test patches dir
load_patch() {
  cp "$FIXTURES/$1" "$TEST_PATCHES/patches/"
}

# Apply patches for a given deployment
apply() {
  bash "$CLI" apply -d "${1:-test-instance}" 2>&1
}

# ── Tests ────────────────────────────────────────────────────────────────────

test_file_step_content_file() {
  setup
  load_patch test-file-step.yaml
  apply test-instance >/dev/null
  [[ -f "$TEST_HOME/workspace/test-content.txt" ]]
  grep -q "test content from a file step" "$TEST_HOME/workspace/test-content.txt"
  teardown
}

test_file_step_inline() {
  setup
  load_patch test-file-inline.yaml
  apply test-instance >/dev/null
  [[ -f "$TEST_HOME/workspace/inline-test.txt" ]]
  grep -q "hello from inline" "$TEST_HOME/workspace/inline-test.txt"
  teardown
}

test_file_step_append() {
  setup
  # Create existing file
  mkdir -p "$TEST_HOME/workspace"
  echo "original line" > "$TEST_HOME/workspace/appendable.txt"
  load_patch test-file-append.yaml
  apply test-instance >/dev/null
  # Original content should still be there
  grep -q "original line" "$TEST_HOME/workspace/appendable.txt"
  # Appended content should be there too
  grep -q "appended line" "$TEST_HOME/workspace/appendable.txt"
  teardown
}

test_file_step_append_marker() {
  setup
  mkdir -p "$TEST_HOME/workspace"
  echo "existing content" > "$TEST_HOME/workspace/marked.txt"
  load_patch test-file-append-marker.yaml
  apply test-instance >/dev/null
  # Marker content should be appended
  grep -q "## Custom Section" "$TEST_HOME/workspace/marked.txt"
  grep -q "existing content" "$TEST_HOME/workspace/marked.txt"
  teardown
}

test_file_step_append_marker_idempotent() {
  setup
  mkdir -p "$TEST_HOME/workspace"
  # File already contains the marker
  printf 'existing content\n## Custom Section\nSome new content\n' > "$TEST_HOME/workspace/marked.txt"
  load_patch test-file-append-marker.yaml
  apply test-instance >/dev/null
  # Should NOT append again — count occurrences of marker
  local count
  count="$(grep -c "## Custom Section" "$TEST_HOME/workspace/marked.txt")"
  [[ "$count" -eq 1 ]]
  teardown
}

test_config_patch_existing() {
  setup
  # Create an existing openclaw.json
  mkdir -p "$TEST_HOME"
  echo '{"existing": true, "models": {"other": "foo"}}' > "$TEST_HOME/openclaw.json"
  load_patch test-config-patch.yaml
  apply test-instance >/dev/null
  # Check deep merge happened
  jq -e '.existing == true' "$TEST_HOME/openclaw.json" >/dev/null
  jq -e '.models.default == "anthropic/claude-sonnet-4-20250514"' "$TEST_HOME/openclaw.json" >/dev/null
  jq -e '.models.other == "foo"' "$TEST_HOME/openclaw.json" >/dev/null
  jq -e '.testKey == "testValue"' "$TEST_HOME/openclaw.json" >/dev/null
  teardown
}

test_config_patch_missing_config() {
  setup
  # No openclaw.json exists — should fail with clear error
  load_patch test-config-patch.yaml
  local output
  output="$(apply test-instance 2>&1)" || true
  echo "$output" | grep -q "openclaw onboard"
  [[ ! -f "$TEST_HOME/openclaw.json" ]]
  teardown
}

test_config_set() {
  setup
  setup_mock_openclaw
  load_patch test-config-set.yaml
  apply test-instance >/dev/null
  # Verify openclaw config set was called with the right args
  grep -q "config set models.default anthropic/claude-sonnet-4-20250514" "$TEST_HOME/mock-openclaw-calls.txt"
  teardown
}

test_config_append() {
  setup
  # Need a mock that handles config get + config set with real JSON
  mkdir -p "$TEST_HOME"
  echo '{"skills":{"load":{"extraDirs":["existing-dir"]}}}' > "$TEST_HOME/openclaw.json"
  cat > "$MOCK_BIN/openclaw" << 'MOCK'
#!/usr/bin/env bash
CONFIG="${OPENCLAW_CONFIG_PATH:-$OPENCLAW_HOME/openclaw.json}"
if [[ "$1" == "config" && "$2" == "get" ]]; then
  path="$3"
  jq_path=$(echo "$path" | sed 's/\./","/g' | sed 's/^/["/' | sed 's/$/"]/')
  jq "getpath($jq_path)" "$CONFIG"
  exit 0
fi
if [[ "$1" == "config" && "$2" == "set" ]]; then
  path="$3"
  value="$4"
  tmp=$(mktemp)
  jq_path=$(echo "$path" | sed 's/\./","/g' | sed 's/^/["/' | sed 's/$/"]/')
  if echo "$value" | jq empty 2>/dev/null; then
    jq --argjson v "$value" "setpath($jq_path; \$v)" "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
  else
    jq --arg v "$value" "setpath($jq_path; \$v)" "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
  fi
  exit 0
fi
if [[ "$1" == "cron" && "$2" == "list" && "$*" == *"--json"* ]]; then
  echo "[]"
fi
MOCK
  chmod +x "$MOCK_BIN/openclaw"
  export PATH="$MOCK_BIN:$PATH"
  load_patch test-config-append.yaml
  apply test-instance >/dev/null
  # New value should be present
  jq -e '.skills.load.extraDirs | index("~/.agents/skills")' "$TEST_HOME/openclaw.json" >/dev/null
  # Existing value should be preserved
  jq -e '.skills.load.extraDirs | index("existing-dir")' "$TEST_HOME/openclaw.json" >/dev/null
  teardown
}

test_config_append_idempotent() {
  setup
  # Start with the value already present
  mkdir -p "$TEST_HOME"
  echo '{"skills":{"load":{"extraDirs":["~/.agents/skills"]}}}' > "$TEST_HOME/openclaw.json"
  cat > "$MOCK_BIN/openclaw" << 'MOCK'
#!/usr/bin/env bash
CONFIG="${OPENCLAW_CONFIG_PATH:-$OPENCLAW_HOME/openclaw.json}"
if [[ "$1" == "config" && "$2" == "get" ]]; then
  path="$3"
  jq_path=$(echo "$path" | sed 's/\./","/g' | sed 's/^/["/' | sed 's/$/"]/')
  jq "getpath($jq_path)" "$CONFIG"
  exit 0
fi
if [[ "$1" == "config" && "$2" == "set" ]]; then
  path="$3"
  value="$4"
  tmp=$(mktemp)
  jq_path=$(echo "$path" | sed 's/\./","/g' | sed 's/^/["/' | sed 's/$/"]/')
  if echo "$value" | jq empty 2>/dev/null; then
    jq --argjson v "$value" "setpath($jq_path; \$v)" "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
  else
    jq --arg v "$value" "setpath($jq_path; \$v)" "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
  fi
  exit 0
fi
if [[ "$1" == "cron" && "$2" == "list" && "$*" == *"--json"* ]]; then
  echo "[]"
fi
MOCK
  chmod +x "$MOCK_BIN/openclaw"
  export PATH="$MOCK_BIN:$PATH"
  load_patch test-config-append.yaml
  apply test-instance >/dev/null
  # Should have exactly 1 entry (deduplicated)
  local count
  count=$(jq '.skills.load.extraDirs | length' "$TEST_HOME/openclaw.json")
  [[ "$count" -eq 1 ]]
  teardown
}

test_mkdir_step() {
  setup
  load_patch test-mkdir-step.yaml
  apply test-instance >/dev/null
  [[ -d "$TEST_HOME/workspace/memory/daily" ]]
  [[ -d "$TEST_HOME/workspace/research" ]]
  teardown
}

test_skill_step() {
  setup
  load_patch test-skill-step.yaml
  apply test-instance >/dev/null
  [[ -f "$TEST_HOME/skills/test-skill/SKILL.md" ]]
  grep -q "Test Skill" "$TEST_HOME/skills/test-skill/SKILL.md"
  teardown
}

test_cron_step() {
  setup
  setup_mock_openclaw
  load_patch test-cron-step.yaml
  apply test-instance >/dev/null
  # Verify openclaw cron add was called with the right flags
  local calls="$TEST_HOME/mock-openclaw-calls.txt"
  grep -q "cron add" "$calls"
  grep -q -- "--name test-cron-job" "$calls"
  grep -q -- "--cron 0 9 \* \* \*" "$calls" || grep -q "0 9" "$calls"
  grep -q -- "--message Run test cron" "$calls"
  grep -q -- "--announce" "$calls"
  teardown
}

test_cron_step_idempotent() {
  setup
  MOCK_BIN_CRON="$(mktemp -d)"
  # Mock openclaw that returns an existing cron job
  cat > "$MOCK_BIN_CRON/openclaw" << 'MOCK'
#!/usr/bin/env bash
echo "$@" >> "${OPENCLAW_HOME}/mock-openclaw-calls.txt"
if [[ "$1" == "cron" && "$2" == "list" && "$*" == *"--json"* ]]; then
  echo '[{"name":"test-cron-job","schedule":"0 9 * * *"}]'
fi
MOCK
  chmod +x "$MOCK_BIN_CRON/openclaw"
  export PATH="$MOCK_BIN_CRON:$PATH"
  load_patch test-cron-step.yaml
  apply test-instance >/dev/null
  # Should NOT have called cron add (skipped because job exists)
  ! grep -q "cron add" "$TEST_HOME/mock-openclaw-calls.txt" 2>/dev/null
  rm -rf "$MOCK_BIN_CRON"
  teardown
}

test_openclaw_update() {
  setup
  setup_mock_openclaw
  load_patch test-openclaw-update.yaml
  apply test-instance >/dev/null
  # Verify openclaw update --yes --tag 1.2.3 was called
  grep -q "update --yes --tag 1.2.3" "$TEST_HOME/mock-openclaw-calls.txt"
  teardown
}

test_exec_step() {
  setup
  load_patch test-exec-step.yaml
  apply test-instance >/dev/null
  [[ -f "$TEST_HOME/exec-marker.txt" ]]
  grep -q "test-exec-marker" "$TEST_HOME/exec-marker.txt"
  teardown
}

test_restart_step() {
  setup
  setup_mock_openclaw
  load_patch test-restart-step.yaml
  apply test-instance >/dev/null
  # Should have called openclaw gateway restart
  grep -q "gateway restart" "$TEST_HOME/mock-openclaw-calls.txt"
  # Patch should be marked applied
  jq -e '.["test-restart-step"] != null' "$TEST_HOME/patches/applied.json" >/dev/null
  teardown
}

test_full_patch() {
  setup
  # Need an existing config for the config_patch step to merge into
  mkdir -p "$TEST_HOME"
  echo '{"existing": true}' > "$TEST_HOME/openclaw.json"
  load_patch test-full-patch.yaml
  apply test-instance >/dev/null
  # file step
  grep -q "from full patch" "$TEST_HOME/workspace/full-test.txt"
  # config_patch step
  jq -e '.testKey == "testValue"' "$TEST_HOME/openclaw.json" >/dev/null
  # exec step
  grep -q "full-patch-marker" "$TEST_HOME/full-marker.txt"
  teardown
}

test_idempotency() {
  setup
  load_patch test-exec-step.yaml
  # Apply once
  apply test-instance >/dev/null
  [[ -f "$TEST_HOME/exec-marker.txt" ]]
  # Remove the marker file
  rm "$TEST_HOME/exec-marker.txt"
  # Apply again — should be a no-op (already applied)
  local output
  output="$(apply test-instance)"
  echo "$output" | grep -q "0 applied"
  # Marker file should NOT reappear
  [[ ! -f "$TEST_HOME/exec-marker.txt" ]]
  teardown
}

test_target_filter_match() {
  setup
  load_patch test-target-filter.yaml
  apply opensesame >/dev/null
  # Should have been applied to opensesame
  [[ -f "$TEST_HOME/workspace/target-only.txt" ]]
  teardown
}

test_target_filter_skip() {
  setup
  load_patch test-target-filter.yaml
  apply mac-mini >/dev/null
  # Should NOT have been applied to mac-mini
  [[ ! -f "$TEST_HOME/workspace/target-only.txt" ]]
  teardown
}

test_chronological_ordering() {
  setup
  # Load both ordering patches (b has later timestamp than a)
  load_patch test-ordering-a.yaml
  load_patch test-ordering-b.yaml
  apply test-instance >/dev/null
  # order-test.txt should contain A then B (chronological order)
  local first second
  first="$(head -1 "$TEST_HOME/order-test.txt")"
  second="$(tail -1 "$TEST_HOME/order-test.txt")"
  [[ "$first" == "A" && "$second" == "B" ]]
  teardown
}

test_validate_no_patches() {
  setup
  # No patches loaded — validate should succeed
  bash "$CLI" validate >/dev/null 2>&1
  teardown
}

test_list_empty() {
  setup
  local output
  output="$(bash "$CLI" list 2>&1)"
  echo "$output" | grep -q "no patches yet"
  teardown
}

test_two_space_indent() {
  setup
  # Create a patch with 2-space indentation
  cat > "$TEST_PATCHES/patches/two-space.yaml" << 'YAML'
id: two-space
description: "2-space indent test"
targets: ["*"]
created: 2026-01-01T00:00:00Z

steps:
  - type: exec
    command: "echo two-space-ok > $OPENCLAW_HOME/two-space.txt"
YAML
  apply test-instance >/dev/null
  [[ -f "$TEST_HOME/two-space.txt" ]]
  grep -q "two-space-ok" "$TEST_HOME/two-space.txt"
  teardown
}

test_requires_blocks_missing_vars() {
  setup
  load_patch test-requires-missing.yaml
  local output
  output="$(apply test-instance 2>&1)"
  [[ ! -f "$TEST_HOME/requires-marker.txt" ]]
  echo "$output" | grep -q "skipped (missing env)"
  teardown
}

test_requires_allows_satisfied_vars() {
  setup
  load_patch test-requires-satisfied.yaml
  apply test-instance >/dev/null
  [[ -f "$TEST_HOME/requires-satisfied-marker.txt" ]]
  grep -q "requires-ok" "$TEST_HOME/requires-satisfied-marker.txt"
  teardown
}

test_plugin_enable_step() {
  setup
  setup_mock_openclaw
  cat > "$TEST_PATCHES/patches/plugin-enable-test.yaml" << YAML
id: plugin-enable-test
description: "Test plugin_enable step"
targets: ["*"]
created: 2026-01-01T00:00:22Z

steps:
  - type: plugin_enable
    plugin: discord
YAML
  apply test-instance >/dev/null
  grep -q "plugins enable discord" "$TEST_HOME/mock-openclaw-calls.txt"
  teardown
}

test_extension_step() {
  setup
  # Mock openclaw that handles "plugins install <path>" by copying the dir
  cat > "$MOCK_BIN/openclaw" << 'MOCK'
#!/usr/bin/env bash
echo "$@" >> "${OPENCLAW_HOME}/mock-openclaw-calls.txt"
if [[ "$1" == "plugins" && "$2" == "install" && -n "$3" ]]; then
  # Mimic real CLI: copy source dir into extensions/
  local src="$3"
  local name="$(basename "$src")"
  local dest="$OPENCLAW_HOME/extensions/$name"
  mkdir -p "$dest"
  cp -r "$src"/* "$dest/"
fi
if [[ "$1" == "cron" && "$2" == "list" && "$*" == *"--json"* ]]; then
  echo "[]"
fi
MOCK
  chmod +x "$MOCK_BIN/openclaw"
  export PATH="$MOCK_BIN:$PATH"
  load_patch test-extension-step.yaml
  apply test-instance >/dev/null
  # Verify files were installed
  [[ -f "$TEST_HOME/extensions/test-extension/openclaw.plugin.json" ]]
  [[ -f "$TEST_HOME/extensions/test-extension/index.ts" ]]
  jq -e '.id == "test-extension"' "$TEST_HOME/extensions/test-extension/openclaw.plugin.json" >/dev/null
  # Verify openclaw plugins install was called
  grep -q "plugins install" "$TEST_HOME/mock-openclaw-calls.txt"
  # enable: false, so plugins enable should NOT have been called
  ! grep -q "plugins enable" "$TEST_HOME/mock-openclaw-calls.txt" 2>/dev/null
  teardown
}

# ── Run ──────────────────────────────────────────────────────────────────────

echo "openclaw-patch test suite"
echo "========================="
echo ""

run_test "file step (content_file)"       test_file_step_content_file
run_test "file step (inline content)"     test_file_step_inline
run_test "file step (append)"             test_file_step_append
run_test "file step (append + marker)"    test_file_step_append_marker
run_test "file step (marker idempotent)"  test_file_step_append_marker_idempotent
run_test "config_patch (existing config)" test_config_patch_existing
run_test "config_patch (missing config)"  test_config_patch_missing_config
run_test "config_set"                     test_config_set
run_test "config_append"                  test_config_append
run_test "config_append (idempotent)"     test_config_append_idempotent
run_test "mkdir step"                     test_mkdir_step
run_test "skill step"                     test_skill_step
run_test "cron step (openclaw CLI)"       test_cron_step
run_test "cron step (idempotent skip)"    test_cron_step_idempotent
run_test "exec step"                      test_exec_step
run_test "openclaw_update (with tag)"     test_openclaw_update
run_test "restart step (openclaw CLI)"    test_restart_step
run_test "full multi-step patch"          test_full_patch
run_test "idempotency (second apply=nop)" test_idempotency
run_test "target filter (match)"          test_target_filter_match
run_test "target filter (skip)"           test_target_filter_skip
run_test "chronological ordering"         test_chronological_ordering
run_test "validate with no patches"       test_validate_no_patches
run_test "list shows empty"               test_list_empty
run_test "2-space indent parsing"         test_two_space_indent
run_test "requires blocks missing vars"   test_requires_blocks_missing_vars
run_test "requires allows satisfied vars" test_requires_allows_satisfied_vars
run_test "plugin_enable step"             test_plugin_enable_step
run_test "extension step"                test_extension_step

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
