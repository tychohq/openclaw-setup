#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
UPGRADE_SCRIPT="$ROOT_DIR/shared/scripts/openclaw-upgrade"
ORIG_PATH="$PATH"
CURRENT_SCENARIO=""

pass() { printf 'PASS %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1" >&2; exit 1; }

assert_eq() {
  local actual="$1" expected="$2" message="$3"
  [[ "$actual" == "$expected" ]] || fail "$message (expected=$expected actual=$actual)"
}

assert_file_contains() {
  local file="$1" needle="$2" message="$3"
  grep -F "$needle" "$file" >/dev/null 2>&1 || fail "$message"
}

assert_exists() {
  local path="$1" message="$2"
  [[ -e "$path" ]] || fail "$message"
}

assert_not_exists() {
  local path="$1" message="$2"
  [[ ! -e "$path" ]] || fail "$message"
}

create_stub_bin() {
  local bin_dir="$1"
  mkdir -p "$bin_dir"

  cat > "$bin_dir/openclaw" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
SCENARIO_DIR="${OPENCLAW_TEST_SCENARIO:?}"
OPENCLAW_HOME="${OPENCLAW_HOME:?}"
printf '%s\n' "$*" >> "$SCENARIO_DIR/openclaw.calls"
command_name="$1"
subcommand="${2:-}"
shift || true
shift || true

case "$command_name $subcommand" in
  "gateway status") printf '{"service":{"loaded":true,"label":"openclaw-gateway"}}\n'; exit 0 ;;
  "gateway install") printf '{"status":"ok"}\n'; exit 0 ;;
  "update status") printf '{"update":{"installKind":"package","root":"%s"},"channel":{"value":"stable"}}\n' "$SCENARIO_DIR/update-root"; exit 0 ;;
esac

if [[ "$command_name" == "update" ]]; then
  if [[ " $* " == *" --dry-run "* ]]; then
    printf '{"dryRun":true,"currentVersion":"1.0.0","targetVersion":"1.1.0","installKind":"package"}\n'
    exit 0
  fi
  if [[ "$*" == *" --tag 1.0.0"* ]]; then
    printf '{"status":"ok","before":{"version":"1.1.0"},"after":{"version":"1.0.0"}}\n'
    exit 0
  fi
  if [[ "${OPENCLAW_TEST_MUTATE_FILES:-0}" == "1" ]]; then
    mkdir -p "$OPENCLAW_HOME/agents/main/agent" "$OPENCLAW_HOME/workspace/config"
    printf '{"changed":true}\n' > "$OPENCLAW_HOME/openclaw.json"
    printf 'MUTATED=1\n' > "$OPENCLAW_HOME/.env"
    printf '{"profiles":{"mutated":true}}\n' > "$OPENCLAW_HOME/agents/main/agent/auth-profiles.json"
    printf '{"workspace":"mutated"}\n' > "$OPENCLAW_HOME/workspace/config/workspace-manifest.json"
  fi
  printf '{"status":"ok","before":{"version":"1.0.0"},"after":{"version":"1.1.0"}}\n'
  exit 0
fi

if [[ "$command_name" == "doctor" ]]; then exit 0; fi
if [[ "$command_name" == "config" && "$subcommand" == "get" ]]; then printf 'false\n'; exit 0; fi
if [[ "$command_name" == "config" && "$subcommand" == "set" ]]; then exit 0; fi
if [[ "$command_name" == "cron" && "$subcommand" == "list" ]]; then printf '[{"id":"daily","name":"Daily check"}]\n'; exit 0; fi
if [[ "$command_name" == "cron" && "$subcommand" == "status" ]]; then printf '{"status":"ok"}\n'; exit 0; fi
if [[ "$command_name" == "skills" && "$subcommand" == "list" ]]; then printf '[{"name":"browser"},{"name":"memory"}]\n'; exit 0; fi
if [[ "$command_name" == "health" ]]; then
  if [[ -f "$SCENARIO_DIR/health.fail" ]]; then
    printf '{"status":"failing"}\n'
    exit 1
  fi
  printf '{"status":"ok","version":"1.1.0"}\n'
  exit 0
fi
if [[ "$command_name" == "message" && "$subcommand" == "send" ]]; then printf '{"status":"ok"}\n'; exit 0; fi

printf 'Unhandled openclaw stub command: %s %s\n' "$command_name" "$subcommand" >&2
exit 1
STUB
  chmod +x "$bin_dir/openclaw"

  cat > "$bin_dir/systemctl" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
SCENARIO_DIR="${OPENCLAW_TEST_SCENARIO:?}"
printf '%s\n' "$*" >> "$SCENARIO_DIR/systemctl.calls"
if [[ "$1 $2" == "--user restart" ]]; then
  count_file="$SCENARIO_DIR/systemctl.restart.count"
  count=0
  [[ -f "$count_file" ]] && count="$(cat "$count_file")"
  count=$((count + 1))
  printf '%s\n' "$count" > "$count_file"
  if [[ "${OPENCLAW_TEST_REMOVE_HEALTH_FAIL_ON_SECOND_RESTART:-0}" == "1" && "$count" -ge 2 ]]; then
    rm -f "$SCENARIO_DIR/health.fail"
  fi
fi
exit 0
STUB
  chmod +x "$bin_dir/systemctl"
}

run_upgrade() {
  local workdir="$1"
  shift
  local rc=0
  (
    cd "$workdir"
    "$UPGRADE_SCRIPT" "$@"
  ) || rc=$?
  printf '%s\n' "$rc"
}

setup_scenario() {
  local name="$1"
  local base="$2"
  local scenario_dir="$base/$name"
  local bin_dir="$scenario_dir/bin"
  local home_dir="$scenario_dir/home/.openclaw"
  mkdir -p "$scenario_dir" "$home_dir"
  create_stub_bin "$bin_dir"
  printf '%s\n' "$scenario_dir/update-root" > "$scenario_dir/update-root"

  export OPENCLAW_TEST_SCENARIO="$scenario_dir"
  export OPENCLAW_HOME="$home_dir"
  export OPENCLAW_UPGRADE_PLATFORM="linux"
  export PATH="$bin_dir:$ORIG_PATH"
  unset OPENCLAW_TEST_MUTATE_FILES OPENCLAW_TEST_REMOVE_HEALTH_FAIL_ON_SECOND_RESTART

  printf '{"original":true}\n' > "$home_dir/openclaw.json"
  printf 'ORIGINAL=1\n' > "$home_dir/.env"
  mkdir -p "$home_dir/agents/main/agent" "$home_dir/workspace/config"
  printf '{"profiles":{"original":true}}\n' > "$home_dir/agents/main/agent/auth-profiles.json"
  printf '{"workspace":"original"}\n' > "$home_dir/workspace/config/workspace-manifest.json"

  CURRENT_SCENARIO="$scenario_dir"
}

test_dry_run() {
  local base scenario rc log_file
  base="$(mktemp -d "${TMPDIR:-/tmp}/openclaw-upgrade-tests.XXXXXX")"
  setup_scenario dry-run "$base"
  scenario="$CURRENT_SCENARIO"
  rc="$(run_upgrade "$ROOT_DIR" --dry-run)"
  assert_eq "$rc" "0" "dry-run should exit 0"
  assert_file_contains "$scenario/openclaw.calls" "update --json --no-restart --dry-run --timeout 1200 --channel stable" "dry-run should invoke update --dry-run"
  if compgen -G "$OPENCLAW_HOME/backups/upgrade-*" >/dev/null; then fail "dry-run should not create backup directories"; fi
  assert_not_exists "$scenario/systemctl.calls" "dry-run should not restart via systemctl"
  log_file="$(ls "$OPENCLAW_HOME"/logs/upgrade-*.log | head -1)"
  assert_exists "$log_file" "dry-run should create a log file"
  pass "dry-run"
  rm -rf "$base"
}

test_lock_behavior() {
  local base scenario rc sleeper
  base="$(mktemp -d "${TMPDIR:-/tmp}/openclaw-upgrade-tests.XXXXXX")"
  setup_scenario lock "$base"
  scenario="$CURRENT_SCENARIO"
  sleep 30 &
  sleeper=$!
  printf '{"pid":%s,"started_at":"2026-03-06T00:00:00Z","hostname":"test"}\n' "$sleeper" > "$OPENCLAW_HOME/.upgrade-lock"
  rc="$(run_upgrade "$ROOT_DIR" --dry-run)"
  assert_eq "$rc" "2" "live lock should exit 2"
  kill "$sleeper" >/dev/null 2>&1 || true
  wait "$sleeper" 2>/dev/null || true
  printf '{"pid":999999,"started_at":"2026-03-06T00:00:00Z","hostname":"test"}\n' > "$OPENCLAW_HOME/.upgrade-lock"
  rc="$(run_upgrade "$ROOT_DIR" --dry-run)"
  assert_eq "$rc" "0" "stale lock should be cleared"
  assert_not_exists "$OPENCLAW_HOME/.upgrade-lock" "stale lock should be removed after success"
  pass "lock behavior"
  rm -rf "$base"
}

test_backup_restore() {
  local base scenario rc latest_backup
  base="$(mktemp -d "${TMPDIR:-/tmp}/openclaw-upgrade-tests.XXXXXX")"
  setup_scenario restore "$base"
  scenario="$CURRENT_SCENARIO"
  export OPENCLAW_TEST_MUTATE_FILES=1
  export OPENCLAW_TEST_REMOVE_HEALTH_FAIL_ON_SECOND_RESTART=1
  : > "$scenario/health.fail"
  rc="$(run_upgrade "$ROOT_DIR" --health-timeout 1 --health-interval 1)"
  assert_eq "$rc" "3" "rollback path should exit 3"
  assert_file_contains "$OPENCLAW_HOME/openclaw.json" '"original":true' "openclaw.json should be restored"
  assert_file_contains "$OPENCLAW_HOME/.env" 'ORIGINAL=1' ".env should be restored"
  assert_file_contains "$OPENCLAW_HOME/agents/main/agent/auth-profiles.json" '"original":true' "auth profiles should be restored"
  assert_file_contains "$OPENCLAW_HOME/workspace/config/workspace-manifest.json" '"original"' "workspace manifest should be restored"
  latest_backup="$(ls -1dt "$OPENCLAW_HOME"/backups/upgrade-* | head -1)"
  assert_exists "$latest_backup/result.json" "result.json should be written for rollback runs"
  assert_file_contains "$latest_backup/result.json" 'rollback_success' "result.json should report rollback success"
  pass "backup restore"
  rm -rf "$base"
}

main() {
  test_dry_run
  test_lock_behavior
  test_backup_restore
}

main "$@"
