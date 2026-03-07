#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-lib.sh"

PASS=0
FAIL=0
SKIP=0
TOTAL=0
SKIP_EXIT=200

skip_test() {
  echo "$*"
  return "$SKIP_EXIT"
}

print_test_output() {
  local output="$1"
  [[ -z "$output" ]] && return 0

  while IFS= read -r line; do
    echo "    $line"
  done <<< "$output"
}

run_test() {
  local name="$1"
  local fn="$2"
  local output_file
  local status

  TOTAL=$((TOTAL + 1))
  printf '  %s ... ' "$name"

  output_file="$(mktemp)"
  set +e
  (
    "$fn"
  ) >"$output_file" 2>&1
  status=$?
  set -e

  case "$status" in
    0)
      echo "PASS"
      PASS=$((PASS + 1))
      ;;
    "$SKIP_EXIT")
      echo "SKIP"
      SKIP=$((SKIP + 1))
      print_test_output "$(cat "$output_file")"
      ;;
    *)
      echo "FAIL"
      FAIL=$((FAIL + 1))
      print_test_output "$(cat "$output_file")"
      ;;
  esac

  rm -f "$output_file"
}

test_file_step_content_file() {
  setup_test_env --fixtures
  load_fixture_patch test-file-step.yaml
  apply_patches test-instance >/dev/null
  [[ -f "$OPENCLAW_HOME/workspace/test-content.txt" ]]
  grep -q "test content from a file step" "$OPENCLAW_HOME/workspace/test-content.txt"
}

test_file_step_inline() {
  setup_test_env --fixtures
  load_fixture_patch test-file-inline.yaml
  apply_patches test-instance >/dev/null
  [[ -f "$OPENCLAW_HOME/workspace/inline-test.txt" ]]
  grep -q "hello from inline" "$OPENCLAW_HOME/workspace/inline-test.txt"
}

test_file_step_append() {
  setup_test_env --fixtures
  mkdir -p "$OPENCLAW_HOME/workspace"
  echo "original line" > "$OPENCLAW_HOME/workspace/appendable.txt"
  load_fixture_patch test-file-append.yaml
  apply_patches test-instance >/dev/null
  grep -q "original line" "$OPENCLAW_HOME/workspace/appendable.txt"
  grep -q "appended line" "$OPENCLAW_HOME/workspace/appendable.txt"
}

test_file_step_append_marker() {
  setup_test_env --fixtures
  mkdir -p "$OPENCLAW_HOME/workspace"
  echo "existing content" > "$OPENCLAW_HOME/workspace/marked.txt"
  load_fixture_patch test-file-append-marker.yaml
  apply_patches test-instance >/dev/null
  grep -q "## Custom Section" "$OPENCLAW_HOME/workspace/marked.txt"
  grep -q "existing content" "$OPENCLAW_HOME/workspace/marked.txt"
}

test_file_step_append_marker_idempotent() {
  setup_test_env --fixtures
  mkdir -p "$OPENCLAW_HOME/workspace"
  printf 'existing content\n## Custom Section\nSome new content\n' > "$OPENCLAW_HOME/workspace/marked.txt"
  load_fixture_patch test-file-append-marker.yaml
  apply_patches test-instance >/dev/null

  local count
  count="$(grep -c "## Custom Section" "$OPENCLAW_HOME/workspace/marked.txt")"
  [[ "$count" -eq 1 ]]
}

test_config_set() {
  setup_test_env --fixtures
  load_fixture_patch test-config-set.yaml
  apply_patches test-instance >/dev/null
  jq -e '.tools.web.search.provider == "gemini"' "$OPENCLAW_CONFIG_PATH" >/dev/null
}

test_config_append() {
  setup_test_env --fixtures
  openclaw_config_set skills.load.extraDirs '["existing-dir"]' >/dev/null
  load_fixture_patch test-config-append.yaml
  apply_patches test-instance >/dev/null
  jq -e '.skills.load.extraDirs | index("~/.agents/skills") != null' "$OPENCLAW_CONFIG_PATH" >/dev/null
  jq -e '.skills.load.extraDirs | index("existing-dir") != null' "$OPENCLAW_CONFIG_PATH" >/dev/null
}

test_config_append_idempotent() {
  setup_test_env --fixtures
  openclaw_config_set skills.load.extraDirs '["~/.agents/skills"]' >/dev/null
  load_fixture_patch test-config-append.yaml
  apply_patches test-instance >/dev/null

  local count
  count="$(jq '.skills.load.extraDirs | map(select(. == "~/.agents/skills")) | length' "$OPENCLAW_CONFIG_PATH")"
  [[ "$count" -eq 1 ]]
}

test_mkdir_step() {
  setup_test_env --fixtures
  load_fixture_patch test-mkdir-step.yaml
  apply_patches test-instance >/dev/null
  [[ -d "$OPENCLAW_HOME/workspace/memory/daily" ]]
  [[ -d "$OPENCLAW_HOME/workspace/research" ]]
}

test_skill_step() {
  setup_test_env --fixtures
  load_fixture_patch test-skill-step.yaml
  apply_patches test-instance >/dev/null
  [[ -f "$OPENCLAW_HOME/skills/test-skill/SKILL.md" ]]
  grep -q "Test Skill" "$OPENCLAW_HOME/skills/test-skill/SKILL.md"
}

test_cron_step() {
  setup_test_env --fixtures --gateway
  load_fixture_patch test-cron-step.yaml

  local first_output second_output jobs_json
  first_output="$(apply_patches test-instance)"
  echo "$first_output" | grep -q 'Summary: 1 applied'

  jobs_json="$(cron_list_json)"
  echo "$jobs_json" | jq -e '.jobs | length == 1' >/dev/null
  echo "$jobs_json" | jq -e '.jobs[0].name == "test-cron-job"' >/dev/null
  echo "$jobs_json" | jq -e '.jobs[0].schedule.expr == "0 9 * * *"' >/dev/null
  echo "$jobs_json" | jq -e '.jobs[0].schedule.tz == "America/New_York"' >/dev/null
  echo "$jobs_json" | jq -e '.jobs[0].sessionTarget == "isolated"' >/dev/null
  echo "$jobs_json" | jq -e '.jobs[0].payload.message == "Run test cron"' >/dev/null
  echo "$jobs_json" | jq -e '.jobs[0].payload.timeoutSeconds == 300' >/dev/null
  echo "$jobs_json" | jq -e '.jobs[0].delivery.mode == "announce"' >/dev/null

  second_output="$(apply_patches test-instance)"
  echo "$second_output" | grep -q 'Summary: 0 applied'

  jobs_json="$(cron_list_json)"
  echo "$jobs_json" | jq -e '.jobs | length == 1' >/dev/null
}

test_openclaw_update() {
  if [[ "${RUN_OPENCLAW_UPDATE_TESTS:-0}" != "1" ]]; then
    skip_test 'set RUN_OPENCLAW_UPDATE_TESTS=1 to run openclaw_update smoke tests'
    return $?
  fi

  setup_test_env --fixtures
  load_fixture_patch test-openclaw-update.yaml
  apply_patches test-instance >/dev/null
}

test_exec_step() {
  setup_test_env --fixtures
  load_fixture_patch test-exec-step.yaml
  apply_patches test-instance >/dev/null
  [[ -f "$OPENCLAW_HOME/exec-marker.txt" ]]
  grep -q "test-exec-marker" "$OPENCLAW_HOME/exec-marker.txt"
}

test_restart_step() {
  setup_test_env --fixtures --gateway
  cron_list_json >/dev/null
  load_fixture_patch test-restart-step.yaml
  apply_patches test-instance >/dev/null
  wait_for_gateway
  cron_list_json >/dev/null
  jq -e '.["test-restart-step"] != null' "$OPENCLAW_HOME/patches/applied.json" >/dev/null
}

test_full_patch() {
  setup_test_env --fixtures
  load_fixture_patch test-full-patch.yaml
  apply_patches test-instance >/dev/null
  grep -q "from full patch" "$OPENCLAW_HOME/workspace/full-test.txt"
  grep -q "full-patch-marker" "$OPENCLAW_HOME/full-marker.txt"
}

test_idempotency() {
  setup_test_env --fixtures
  load_fixture_patch test-exec-step.yaml
  apply_patches test-instance >/dev/null
  [[ -f "$OPENCLAW_HOME/exec-marker.txt" ]]
  rm "$OPENCLAW_HOME/exec-marker.txt"

  local output
  output="$(apply_patches test-instance)"
  echo "$output" | grep -q 'Summary: 0 applied'
  [[ ! -f "$OPENCLAW_HOME/exec-marker.txt" ]]
}

test_target_filter_match() {
  setup_test_env --fixtures
  load_fixture_patch test-target-filter.yaml
  apply_patches prod-server >/dev/null
  [[ -f "$OPENCLAW_HOME/workspace/target-only.txt" ]]
}

test_target_filter_skip() {
  setup_test_env --fixtures
  load_fixture_patch test-target-filter.yaml
  apply_patches dev-laptop >/dev/null
  [[ ! -f "$OPENCLAW_HOME/workspace/target-only.txt" ]]
}

test_apply_without_deployment() {
  setup_test_env --fixtures
  load_fixture_patch test-exec-step.yaml

  cd "$TEST_ROOT"
  OPENCLAW_HOME="$OPENCLAW_HOME" \
    OPENCLAW_CONFIG_PATH="$OPENCLAW_CONFIG_PATH" \
    OPENCLAW_PATCHES_DIR="$OPENCLAW_PATCHES_DIR" \
    bash "$PATCH_CLI" apply >/dev/null
  [[ -f "$OPENCLAW_HOME/exec-marker.txt" ]]
  grep -q "test-exec-marker" "$OPENCLAW_HOME/exec-marker.txt"
}

test_status_without_deployment() {
  setup_test_env --fixtures
  local output
  cd "$TEST_ROOT"
  output="$(OPENCLAW_HOME="$OPENCLAW_HOME" \
    OPENCLAW_CONFIG_PATH="$OPENCLAW_CONFIG_PATH" \
    OPENCLAW_PATCHES_DIR="$OPENCLAW_PATCHES_DIR" \
    bash "$PATCH_CLI" status 2>&1)"
  echo "$output" | grep -q 'all targets'
}

test_chronological_ordering() {
  setup_test_env --fixtures
  load_fixture_patch test-ordering-a.yaml
  load_fixture_patch test-ordering-b.yaml
  apply_patches test-instance >/dev/null

  local first second
  first="$(head -1 "$OPENCLAW_HOME/order-test.txt")"
  second="$(tail -1 "$OPENCLAW_HOME/order-test.txt")"
  [[ "$first" == "A" && "$second" == "B" ]]
}

test_validate_no_patches() {
  setup_test_env
  bash "$PATCH_CLI" validate >/dev/null 2>&1
}

test_list_empty() {
  setup_test_env
  local output
  output="$(bash "$PATCH_CLI" list 2>&1)"
  echo "$output" | grep -q 'no patches yet'
}

test_two_space_indent() {
  setup_test_env
  cat > "$TEST_PATCH_ROOT/patches/two-space.yaml" <<'YAML'
id: two-space
description: "2-space indent test"
targets: ["*"]
created: 2026-01-01T00:00:00Z

steps:
  - type: exec
    command: "echo two-space-ok > $OPENCLAW_HOME/two-space.txt"
YAML

  apply_patches test-instance >/dev/null
  [[ -f "$OPENCLAW_HOME/two-space.txt" ]]
  grep -q 'two-space-ok' "$OPENCLAW_HOME/two-space.txt"
}

test_requires_blocks_missing_vars() {
  setup_test_env --fixtures
  load_fixture_patch test-requires-missing.yaml

  local output
  output="$(apply_patches test-instance 2>&1)"
  [[ ! -f "$OPENCLAW_HOME/requires-marker.txt" ]]
  echo "$output" | grep -q 'skipped (missing env)'
}

test_requires_allows_satisfied_vars() {
  setup_test_env --fixtures
  load_fixture_patch test-requires-satisfied.yaml
  apply_patches test-instance >/dev/null
  [[ -f "$OPENCLAW_HOME/requires-satisfied-marker.txt" ]]
  grep -q 'requires-ok' "$OPENCLAW_HOME/requires-satisfied-marker.txt"
}

test_plugin_enable_step() {
  setup_test_env
  cat > "$TEST_PATCH_ROOT/patches/plugin-enable-test.yaml" <<'YAML'
id: plugin-enable-test
description: "Test plugin_enable step"
targets: ["*"]
created: 2026-01-01T00:00:22Z

steps:
  - type: plugin_enable
    plugin: discord
YAML

  apply_patches test-instance >/dev/null
  jq -e '.plugins.entries.discord.enabled == true' "$OPENCLAW_CONFIG_PATH" >/dev/null
}

test_extension_step() {
  setup_test_env --fixtures
  load_fixture_patch test-extension-step.yaml
  apply_patches test-instance >/dev/null

  local extension_dir
  extension_dir="$(extension_install_dir test-extension)"
  [[ -f "$extension_dir/openclaw.plugin.json" ]]
  [[ -f "$extension_dir/index.ts" ]]
  jq -e '.id == "test-extension"' "$extension_dir/openclaw.plugin.json" >/dev/null
  jq -e '.plugins.entries["test-extension"].enabled == false' "$OPENCLAW_CONFIG_PATH" >/dev/null
}

test_no_merge_file_references() {
  local matches
  matches="$(rg -n 'merge_file' "$REPO_ROOT" \
    -g '*.sh' -g '*.yaml' -g '*.ts' -g '*.js' -g '*.md' \
    -g '!**/node_modules/**' -g '!**/meta/**' -g '!**/tests/**' \
    | rg -v 'run-tests\.sh' \
    || true)"
  [[ -z "$matches" ]]
}

test_no_config_patch_references() {
  local matches
  matches="$(rg -n 'config_patch' "$REPO_ROOT" \
    -g '*.sh' -g '*.yaml' -g '*.md' \
    -g '!**/node_modules/**' -g '!**/meta/**' -g '!**/tests/**' \
    | rg -v 'run-tests\.sh' \
    || true)"
  [[ -z "$matches" ]]
}

test_docs_no_stale_files_configs() {
  local matches
  matches="$(rg -n 'files/configs' "$REPO_ROOT" -g '*.md' -g '!**/node_modules/**' -g '!**/meta/**' \
    | rg -v 'run-tests\.sh' \
    || true)"
  [[ -z "$matches" ]]
}

test_step_reference_lists_all_step_types() {
  local step_ref="$SCRIPT_DIR/../docs/step-reference.md"
  [[ -f "$step_ref" ]] || return 1
  [[ -f "$PATCH_CLI" ]] || return 1

  local cli_types
  cli_types="$(rg -o '[a-z_]+\)\s+exec_step' "$PATCH_CLI" | sed -E 's/\).*//' | sort -u)"

  while IFS= read -r stype; do
    [[ -z "$stype" ]] && continue
    grep -qi "\`$stype\`" "$step_ref" || return 1
  done <<< "$cli_types"
}

test_readme_step_table_matches_cli() {
  local readme="$SCRIPT_DIR/../README.md"
  [[ -f "$readme" ]] || return 1
  [[ -f "$PATCH_CLI" ]] || return 1

  local cli_types
  cli_types="$(rg -o '[a-z_]+\)\s+exec_step' "$PATCH_CLI" | sed -E 's/\).*//' | sort -u)"

  while IFS= read -r stype; do
    [[ -z "$stype" ]] && continue
    grep -qi "\`$stype\`" "$readme" || return 1
  done <<< "$cli_types"
}

echo 'openclaw-patch test suite'
echo '========================='
echo ''

run_test 'file step (content_file)'        test_file_step_content_file
run_test 'file step (inline content)'      test_file_step_inline
run_test 'file step (append)'              test_file_step_append
run_test 'file step (append + marker)'     test_file_step_append_marker
run_test 'file step (marker idempotent)'   test_file_step_append_marker_idempotent
run_test 'config_set'                      test_config_set
run_test 'config_append'                   test_config_append
run_test 'config_append (idempotent)'      test_config_append_idempotent
run_test 'mkdir step'                      test_mkdir_step
run_test 'skill step'                      test_skill_step
run_test 'cron step (openclaw CLI)'        test_cron_step
run_test 'exec step'                       test_exec_step
run_test 'openclaw_update (with tag)'      test_openclaw_update
run_test 'restart step (openclaw CLI)'     test_restart_step
run_test 'full multi-step patch'           test_full_patch
run_test 'idempotency (second apply=nop)'  test_idempotency
run_test 'target filter (match)'           test_target_filter_match
run_test 'target filter (skip)'            test_target_filter_skip
run_test 'apply without --deployment'      test_apply_without_deployment
run_test 'status without --deployment'     test_status_without_deployment
run_test 'chronological ordering'          test_chronological_ordering
run_test 'validate with no patches'        test_validate_no_patches
run_test 'list shows empty'                test_list_empty
run_test '2-space indent parsing'          test_two_space_indent
run_test 'requires blocks missing vars'    test_requires_blocks_missing_vars
run_test 'requires allows satisfied vars'  test_requires_allows_satisfied_vars
run_test 'plugin_enable step'              test_plugin_enable_step
run_test 'extension step'                  test_extension_step
run_test 'no merge_file references'        test_no_merge_file_references
run_test 'no config_patch references'      test_no_config_patch_references
run_test 'docs: no files/configs refs'     test_docs_no_stale_files_configs
run_test 'step-reference covers all types' test_step_reference_lists_all_step_types
run_test 'README step table matches CLI'   test_readme_step_table_matches_cli

echo ''
echo "Results: $PASS passed, $SKIP skipped, $FAIL failed, $TOTAL total"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
