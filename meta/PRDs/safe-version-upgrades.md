# PRD: TYC-41 Safe OpenClaw Version Upgrades

## Context

Linear ticket: `TYC-41`

OpenClaw already ships an updater, health checks, and service-manager integration. The missing piece is a repo-owned wrapper that performs upgrades from an external shell process with durable logs, backups, rollback, and OS-level scheduling.

This PRD replaces the earlier draft with contracts that match the current CLI surface and the repo’s actual patch tooling.

## Ground Truth from Current CLI

These commands/flags exist in the installed OpenClaw CLI and are the contracts this implementation should build on:

- `openclaw update --json --no-restart --dry-run --channel <stable|beta|dev> --tag <dist-tag|version> --timeout <seconds> --yes`
- `openclaw update status --json`
- `openclaw doctor --non-interactive --yes`
- `openclaw health --json --timeout <ms>`
- `openclaw gateway status --json`
- `openclaw cron list --json`
- `openclaw cron status --json`
- `openclaw skills list --json`
- `openclaw config get <path> --json`
- `openclaw config set <path> <value>`
- `openclaw message send --channel <type> --target <target> --message <text>`

Related repo-local contract:

- `shared/patches/scripts/openclaw-patch sync --deployment <name>`

Useful JSON fields we can rely on:

- `openclaw gateway status --json` includes `service.loaded` and `service.label`
- `openclaw update status --json` includes `update.installKind`, `update.root`, and git metadata when applicable
- `openclaw update --json` returns `status`, `mode`, `before`, `after`, `reason`, `steps`, and `durationMs`

## Goals

1. Make upgrades safe, repeatable, and observable on single-host deployments.
2. Reuse `openclaw update`, `doctor`, `health`, and gateway service-manager behavior instead of reimplementing them.
3. Preserve local state across upgrades: config, env, auth profiles, workspace manifest, cron jobs, skills.
4. Provide an automatic rollback path when an update or post-update validation fails.
5. Support both macOS launchd and Linux systemd user services.
6. Support a post-upgrade `openclaw-patch sync` step when patch tooling is present.

## Non-Goals

1. Replacing OpenClaw’s updater internals.
2. Fleet rollout / canary orchestration.
3. Adding a new daemon or long-running controller.
4. Depending on non-standard system packages beyond common shell tools.

## Deliverables

### Scripts

1. `shared/scripts/openclaw-upgrade`
   - Main safe-upgrade script.
   - Bash.
   - Cross-platform restart logic.
   - Compatible with manual runs, timer runs, and detached runs.
2. `shared/scripts/openclaw-upgrade-detach`
   - Small wrapper that launches `openclaw-upgrade` in a detached process for any future gateway-triggered flow.
3. `shared/scripts/openclaw-upgrade-timer`
   - Installs/uninstalls/manages the OS scheduler artifacts.
   - Supports `install`, `uninstall`, `status`, `enable`, `disable`, and `run-now`.

### Templates

1. `shared/templates/systemd/openclaw-upgrade.service`
2. `shared/templates/systemd/openclaw-upgrade.timer`
3. `shared/templates/launchd/ai.openclaw.upgrade.plist`
4. `shared/config/openclaw-upgrade.env.template`

### Tests and Docs

1. `shared/scripts/tests/run-tests.sh`
2. Focused test fixtures/helpers under `shared/scripts/tests/fixtures/`
3. README upgrade documentation

## Naming and Runtime Paths

Use `OPENCLAW_HOME` when set; otherwise default to `~/.openclaw`.

Runtime artifacts must use the paths requested in the implementation brief:

```text
$OPENCLAW_HOME/.upgrade-lock
$OPENCLAW_HOME/logs/upgrade-<timestamp>.log
$OPENCLAW_HOME/backups/upgrade-<timestamp>/
```

Backup directory contents:

```text
openclaw.json
.env                         # if present
auth-profiles.json           # if present
workspace-manifest.json      # if present
gateway-status-before.json
update-status-before.json
cron-before.json
cron-status-before.json
skills-before.json
metadata.json
```

The script should also write `result.json` for the final run outcome inside the backup directory when not in `notify-only` mode.

## V1: `shared/scripts/openclaw-upgrade`

### CLI Contract

The main script should expose:

```bash
openclaw-upgrade \
  [--channel stable|beta|dev] \
  [--tag <dist-tag|version>] \
  [--timeout <seconds>] \
  [--health-timeout <seconds>] \
  [--health-interval <seconds>] \
  [--mode apply|notify-only] \
  [--retain-count <n>] \
  [--retain-days <n>] \
  [--disk-threshold-mb <n>] \
  [--deployment <name>] \
  [--webhook <url>] \
  [--notify] \
  [--notify-channel <channel>] \
  [--notify-target <target>] \
  [--with-patches] \
  [--dry-run]
```

Defaults:

- `--channel stable`
- `--timeout 1200`
- `--health-timeout 180`
- `--health-interval 5`
- `--mode apply`
- `--retain-count 10`
- `--retain-days 30`
- `--disk-threshold-mb 200`

### Environment / Config File

The script should optionally source `$OPENCLAW_HOME/openclaw-upgrade.env` before parsing CLI flags. CLI flags always win.

Template keys to support:

- `OPENCLAW_UPGRADE_CHANNEL`
- `OPENCLAW_UPGRADE_TAG`
- `OPENCLAW_UPGRADE_TIMEOUT`
- `OPENCLAW_UPGRADE_HEALTH_TIMEOUT`
- `OPENCLAW_UPGRADE_HEALTH_INTERVAL`
- `OPENCLAW_UPGRADE_MODE`
- `OPENCLAW_UPGRADE_RETAIN_COUNT`
- `OPENCLAW_UPGRADE_RETAIN_DAYS`
- `OPENCLAW_UPGRADE_DISK_THRESHOLD_MB`
- `OPENCLAW_UPGRADE_WEBHOOK`
- `OPENCLAW_UPGRADE_NOTIFY_CHANNEL`
- `OPENCLAW_UPGRADE_NOTIFY_TARGET`
- `OPENCLAW_UPGRADE_DEPLOYMENT`
- `OPENCLAW_UPGRADE_WITH_PATCHES`

### Mode Semantics

1. `apply`
   - Full backup → update → doctor → restart → health → integrity verification → optional patch sync.
2. `notify-only`
   - Preflight + `openclaw update --dry-run --json` + notification.
   - No backup, no update, no restart, no rollback.
3. `--dry-run`
   - Simulate the `apply` flow without mutating OpenClaw state.
   - Still perform argument validation, dependency checks, lock checks, and log output.
   - Skip backup writes, update writes, restore writes, service restart, and backup pruning.

## Preflight Checks

Hard failures:

1. Required commands exist: `openclaw`, `jq`, `git`, `tar`, `date`, `df`, `hostname`.
2. `openclaw gateway status --json` succeeds and reports `service.loaded == true`.
3. `openclaw doctor --non-interactive --yes` exits 0.
4. The backup root is writable.
5. Available disk space at `OPENCLAW_HOME` is at least `disk-threshold-mb`.
6. Lock acquisition succeeds.

Soft warning:

1. `openclaw config get update.auto.enabled --json` returns true.
   - For manual V1 runs, warn and continue.
   - For V2 timer installation, require this to be false and offer to set it via `openclaw config set update.auto.enabled false`.

## Locking Strategy

Use a lock file at `$OPENCLAW_HOME/.upgrade-lock` containing JSON or line-based metadata with at least:

- `pid`
- `started_at`
- `hostname`

Behavior:

1. If the file does not exist, create it atomically.
2. If it exists, read the PID.
3. If `kill -0 <pid>` succeeds, exit with lock-contention code.
4. If the PID is missing or dead, treat it as stale, log that fact, remove it, and retry once.
5. Remove the lock on normal exit and on trapped failure paths.

## Snapshot / Backup Rules

Before starting an actual update, capture:

1. `$OPENCLAW_HOME/openclaw.json`
2. `$OPENCLAW_HOME/.env` if present
3. `$OPENCLAW_HOME/agents/main/agent/auth-profiles.json` if present
4. First existing workspace manifest candidate:
   - `$OPENCLAW_HOME/workspace/config/workspace-manifest.json`
   - `$OPENCLAW_HOME/workspace/workspace-manifest.json`
5. `openclaw gateway status --json`
6. `openclaw update status --json`
7. `openclaw cron list --json`
8. `openclaw cron status --json`
9. `openclaw skills list --json`
10. `metadata.json` containing timestamp, host, platform, requested channel/tag, detected install kind, previous version, previous git SHA, and log path

The backup layout must be deterministic so restore logic and tests can target it directly.

## Main Apply Flow

1. Initialize log path and tee all output into it.
2. Acquire lock.
3. Run preflight checks.
4. Capture pre-update snapshots.
5. Run:

   ```bash
   openclaw update --yes --no-restart --json --timeout "$TIMEOUT" --channel "$CHANNEL" [--tag "$TAG"]
   ```

6. Validate the update result JSON.
   - Treat a non-zero exit or JSON `status != "ok"` as failure.
7. Run `openclaw doctor --non-interactive --yes`.
8. Restart via service manager.
   - macOS default: `launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway`
   - Linux default: `systemctl --user restart openclaw-gateway.service`
   - If `openclaw gateway status --json` reports a different `service.label`, use that for launchd.
9. Poll health until success or timeout:

   ```bash
   openclaw health --json --timeout 10000
   ```

10. Re-run integrity checks:
    - `openclaw cron list --json`
    - `openclaw cron status --json`
    - `openclaw skills list --json`
11. Compare before/after cron and skill inventories.
12. If `--with-patches` is enabled and `openclaw-patch` exists, run patch sync.
13. Prune old backups.
14. Send notifications.

## Integrity Verification

### Cron

Compare pre/post `openclaw cron list --json` by job identifiers and names.

Required checks:

1. Every pre-upgrade job id still exists post-upgrade.
2. Every pre-upgrade job name still exists post-upgrade.
3. `openclaw cron status --json` exits 0.

### Skills

Compare pre/post `openclaw skills list --json` by skill name/id.

Required checks:

1. Post-upgrade skill set must be a superset of the pre-upgrade skill set.
2. Missing skills trigger rollback.

Implementation note: do not overfit to a single JSON shape. Extract skill identifiers defensively with `jq` from common fields such as `name`, `id`, or `slug`.

## Rollback Strategy

Rollback triggers:

1. `openclaw update` fails
2. update JSON reports non-`ok`
3. post-update doctor fails
4. service restart fails
5. health never becomes ready
6. cron integrity check fails
7. skills integrity check fails

Rollback phases:

1. Restore backed-up files (`openclaw.json`, `.env`, auth profiles, workspace manifest).
2. Revert the OpenClaw version:
   - **Package install:** `openclaw update --yes --no-restart --json --tag "$PREV_VERSION"`
   - **Git/source install:** `git -C "$UPDATE_ROOT" checkout "$PREV_GIT_SHA"`, then perform a best-effort dependency/build refresh using the detected package manager and `build` script if available.
3. Restart via service manager.
4. Poll `openclaw health --json --timeout 10000` until healthy or timeout.
5. Run `openclaw doctor --non-interactive --yes`.
6. Emit rollback notification.

Important behavior:

- If rollback succeeds, exit non-zero with the rollback-triggered code requested by implementation.
- If rollback fails, include explicit manual-recovery guidance in the log.

## V3: Post-Upgrade Patch Sync

After a successful upgrade and green health check:

1. If `--with-patches` is enabled and `shared/patches/scripts/openclaw-patch` is executable, run:

   ```bash
   openclaw-patch sync --deployment <name>
   ```

2. The deployment name comes from, in priority order:
   - `--deployment`
   - `OPENCLAW_UPGRADE_DEPLOYMENT`
3. If patch sync is requested but no deployment name is available, fail preflight.
4. If patch sync fails after the gateway is healthy:
   - mark the run as degraded
   - notify about the patch failure
   - do **not** rollback the OpenClaw version unless health later fails

## Logging and Notifications

### Logging

Each run gets a log file:

```text
$OPENCLAW_HOME/logs/upgrade-<timestamp>.log
```

The log must include:

- start/end markers
- invoked options
- structured phase markers
- stdout/stderr from OpenClaw commands
- rollback attempts and result
- final status line with exit code

### Webhook

`--webhook <url>` should POST a JSON body with:

- `status`: `success`, `failure`, `rollback_success`, `rollback_failure`, or `degraded`
- `host`
- `platform`
- `channel`
- `tag`
- `deployment`
- `previous_version`
- `final_version`
- `duration_seconds`
- `log_path`
- `backup_path`
- `patch_status`

### CLI Notification

`--notify` should send a message via `openclaw message send`.

Notification destination resolution:

1. `--notify-channel` / `--notify-target`
2. `OPENCLAW_UPGRADE_NOTIFY_CHANNEL` / `OPENCLAW_UPGRADE_NOTIFY_TARGET`

If `--notify` is set but destination data is missing, log a warning and continue.

## Exit Codes

The implementation brief for this ticket overrides the earlier draft’s granular codes. Use:

| Code | Meaning |
|---|---|
| 0 | Upgrade succeeded |
| 1 | General failure |
| 2 | Lock contention |
| 3 | Rollback triggered |
| 4 | Health check failed |

Internal phases may keep richer status strings in `result.json`, but process exit codes must use the table above.

## V2: `shared/scripts/openclaw-upgrade-timer`

This must manage an OS scheduler, not OpenClaw cron.

### Supported Commands

```bash
openclaw-upgrade-timer install   [--platform auto|macos|linux] [--mode apply|notify-only] [--channel stable|beta|dev] [--deployment <name>] [--dry-run]
openclaw-upgrade-timer uninstall [--platform auto|macos|linux] [--dry-run]
openclaw-upgrade-timer status    [--platform auto|macos|linux]
openclaw-upgrade-timer enable    [--platform auto|macos|linux] [--dry-run]
openclaw-upgrade-timer disable   [--platform auto|macos|linux] [--dry-run]
openclaw-upgrade-timer run-now   [--platform auto|macos|linux] [--dry-run]
```

### Install Behavior

1. Detect platform unless explicitly provided.
2. Ensure log and backup parent directories exist.
3. Check `update.auto.enabled`.
   - If true, either set it to false via `openclaw config set update.auto.enabled false` or refuse install unless `--dry-run`.
4. Render scheduler templates with concrete values:
   - repo root
   - user home
   - selected mode/channel/deployment
   - optional patch flag
5. Install scheduler artifacts.
6. Enable the scheduler unless `--dry-run`.

### Linux Templates

Install targets:

- `~/.config/systemd/user/openclaw-upgrade.service`
- `~/.config/systemd/user/openclaw-upgrade.timer`

Service requirements:

- `Type=oneshot`
- `WorkingDirectory=<repo-root>`
- `ExecStart=<repo-root>/shared/scripts/openclaw-upgrade ...`
- append stdout/stderr to `$HOME/.openclaw/logs/timer.log`

Timer requirements:

- default schedule `03:15`
- `RandomizedDelaySec=1800`
- `Persistent=true`

### macOS Template

Install target:

- `~/Library/LaunchAgents/ai.openclaw.upgrade.plist`

Plist requirements:

- `Label=ai.openclaw.upgrade`
- `ProgramArguments` invoke `/bin/bash -lc '<repo-root>/shared/scripts/openclaw-upgrade ...'`
- `StartCalendarInterval` default `03:15`
- stdout/stderr appended to `$HOME/.openclaw/logs/timer.log`

### Status / Enable / Disable / Run-Now

- `status`
  - Linux: `systemctl --user status openclaw-upgrade.timer` and `list-timers`
  - macOS: `launchctl print gui/$UID/ai.openclaw.upgrade`
- `enable`
  - Linux: `systemctl --user enable --now openclaw-upgrade.timer`
  - macOS: `launchctl bootstrap` / `launchctl enable`
- `disable`
  - Linux: `systemctl --user disable --now openclaw-upgrade.timer`
  - macOS: `launchctl bootout` / `launchctl disable`
- `run-now`
  - Linux: `systemctl --user start openclaw-upgrade.service`
  - macOS: `launchctl kickstart -k gui/$UID/ai.openclaw.upgrade`

## Testing Strategy

Add shell tests under `shared/scripts/tests/` that run without a live OpenClaw install by stubbing external commands through `PATH` and a temporary `OPENCLAW_HOME`.

Minimum required coverage:

1. `dry-run`
   - validates preflight and logging behavior
   - confirms no backup dir is created
   - confirms update command receives `--dry-run`
2. lock behavior
   - detects live lock and exits 2
   - removes stale lock and proceeds
3. backup / restore
   - creates expected snapshot files
   - triggers a controlled failure after backup
   - restores backed-up config/env/auth/workspace files

Recommended implementation detail:

- Write the main script so it can be sourced in tests without auto-running, with a `main` guard:

  ```bash
  if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
  fi
  ```

## Implementation Notes

1. Prefer small shell functions and explicit phase boundaries.
2. Keep parsing and JSON extraction defensive; the CLI is evolving.
3. Keep all file writes under `OPENCLAW_HOME` and repo-owned template/script paths.
4. Do not depend on GNU-only flags when a portable alternative exists.
5. Make it easy to override platform detection and external command paths in tests.

## Acceptance Criteria

### V1

- `shared/scripts/openclaw-upgrade` exists and is executable.
- Default run targets `stable` when no channel is provided.
- Uses `openclaw update --yes --no-restart --json` for the actual update.
- Uses `launchctl kickstart -k` on macOS and `systemctl --user restart ...` on Linux.
- Writes timestamped logs and timestamped backups.
- Uses `$OPENCLAW_HOME/.upgrade-lock` with stale PID recovery.
- Performs rollback on update/post-check failure.
- Returns exit codes `0/1/2/3/4` exactly.
- Supports webhook and CLI notifications.

### V2

- `shared/scripts/openclaw-upgrade-timer` exists and is executable.
- systemd timer/service templates exist.
- launchd plist template exists.
- `install`, `uninstall`, `status`, `enable`, `disable`, and `run-now` work in dry-run mode on both platforms.
- V2 refuses or disables `update.auto.enabled=true`.

### V3

- Successful upgrades can run `openclaw-patch sync --deployment <name>`.
- Patch sync failures are logged and surfaced as degraded, not silently ignored.

## Validation Matrix

Required verification commands after implementation:

```bash
bash shared/scripts/tests/run-tests.sh
bash shared/scripts/openclaw-upgrade --help
bash shared/scripts/openclaw-upgrade --dry-run
bash shared/scripts/openclaw-upgrade-timer install --platform linux --dry-run
bash shared/scripts/openclaw-upgrade-timer install --platform macos --dry-run
```

Live validation on a real host, when available:

```bash
bash shared/scripts/openclaw-upgrade --channel stable
openclaw health --json
openclaw cron list --json
openclaw skills list --json
bash shared/scripts/openclaw-upgrade-timer run-now
```
