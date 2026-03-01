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

  # Copy fixture files/skills into the test patches dir
  mkdir -p "$TEST_PATCHES/patches" "$TEST_PATCHES/files" "$TEST_PATCHES/skills"
  cp -r "$FIXTURES/files/"* "$TEST_PATCHES/files/" 2>/dev/null || true
  cp -r "$FIXTURES/skills/"* "$TEST_PATCHES/skills/" 2>/dev/null || true

  export OPENCLAW_HOME="$TEST_HOME"
  export OPENCLAW_PATCHES_DIR="$TEST_PATCHES"
}

teardown() {
  rm -rf "$TEST_HOME" "$TEST_PATCHES"
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
  load_patch test-cron-step.yaml
  apply test-instance >/dev/null
  [[ -f "$TEST_HOME/workspace/cron-jobs/test-cron-job.json" ]]
  jq -e '.name == "test-cron-job"' "$TEST_HOME/workspace/cron-jobs/test-cron-job.json" >/dev/null
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
  load_patch test-restart-step.yaml
  # restart should not fail even if no gateway is running (non-fatal)
  apply test-instance >/dev/null
  # Just check that the patch was marked applied
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
    command: "echo two-space-ok > ~/.openclaw/two-space.txt"
YAML
  apply test-instance >/dev/null
  [[ -f "$TEST_HOME/two-space.txt" ]]
  grep -q "two-space-ok" "$TEST_HOME/two-space.txt"
  teardown
}

# ── Run ──────────────────────────────────────────────────────────────────────

echo "openclaw-patch test suite"
echo "========================="
echo ""

run_test "file step (content_file)"       test_file_step_content_file
run_test "file step (inline content)"     test_file_step_inline
run_test "config_patch (existing config)" test_config_patch_existing
run_test "config_patch (missing config)"  test_config_patch_missing_config
run_test "skill step"                     test_skill_step
run_test "cron step"                      test_cron_step
run_test "exec step"                      test_exec_step
run_test "restart step (non-fatal)"       test_restart_step
run_test "full multi-step patch"          test_full_patch
run_test "idempotency (second apply=nop)" test_idempotency
run_test "target filter (match)"          test_target_filter_match
run_test "target filter (skip)"           test_target_filter_skip
run_test "chronological ordering"         test_chronological_ordering
run_test "validate with no patches"       test_validate_no_patches
run_test "list shows empty"               test_list_empty
run_test "2-space indent parsing"         test_two_space_indent

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
