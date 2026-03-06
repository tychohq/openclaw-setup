# End-to-End Test Suite Rewrite Spec

## Goal

Rewrite `shared/patches/tests/run-tests.sh` and `shared/patches/tests/integration-test.sh` so they exercise `shared/patches/scripts/openclaw-patch` against the real production `openclaw` CLI, using an isolated temporary OpenClaw home for every test run.

Hard requirements:

- No mock `openclaw` binary.
- No shell reimplementation of `openclaw config get/set` behavior.
- No fake cron responses.
- Use the real `openclaw` binary for all CLI-backed operations: `config get/set`, `plugins enable`, `plugins install`, `cron add/list`, and any gateway interactions.
- Keep all side effects inside a temp directory.

This spec only covers the test harness rewrite. It does not change `openclaw-patch` behavior.

## Why Rewrite

The current suite validates the patch engine, but many of the most important steps are only checked through mocks:

- `config_set` and `config_append` rely on mock `openclaw` binaries.
- `plugin_enable`, `cron`, `restart`, `openclaw_update`, and `extension` are mostly asserted by inspecting logged mock invocations.
- `integration-test.sh` builds a fake `openclaw` shim that mutates JSON with `jq` instead of using the production CLI.

That means the suite can pass while the real CLI fails due to:

- changed command behavior,
- changed output formats,
- changed config validation rules,
- plugin install side effects,
- gateway-dependent cron behavior.

The replacement suite should validate the true production path end-to-end.

## Current Patch Inventory

Production patch files in `shared/patches/patches/` currently use these step types:

- `config_set`
- `config_append`
- `plugin_enable`
- `extension`

They also require these env vars across the current patch set:

- `ANTHROPIC_API_KEY`
- `OPENAI_API_KEY`
- `GEMINI_API_KEY`
- `DISCORD_TOKEN`
- `DISCORD_OWNER_ID`
- `DISCORD_GUILD_ID`
- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_OWNER_ID`
- `SIGNAL_PHONE_NUMBER`
- `SLACK_BOT_TOKEN`
- `SLACK_APP_TOKEN`
- `SLACK_OWNER_USER_ID`

Fixture patches in `shared/patches/tests/fixtures/` additionally cover:

- `file`
- `mkdir`
- `skill`
- `cron`
- `exec`
- `openclaw_update`
- `restart`
- target filtering
- chronological ordering
- requires gates
- idempotency

## Test Design Principles

1. Use one disposable OpenClaw home per test.
2. Point both `OPENCLAW_HOME` and `OPENCLAW_CONFIG_PATH` at that temp home.
3. Write a temp `.env` with dummy values so no real credentials are ever loaded.
4. `cd` into the temp directory before starting the gateway or running CLI commands, because `openclaw` also loads dotenv state from the current working directory.
5. Use the real `openclaw` binary resolved from `command -v openclaw`.
6. Use `jq` only for assertions against the real `openclaw.json`, not to emulate CLI behavior.
7. Keep gateway-backed tests isolated to a dedicated loopback port.

## Real Binary Requirement

The harness should resolve the CLI once at startup:

```bash
OPENCLAW_BIN="${OPENCLAW_BIN:-$(command -v openclaw)}"
[[ -x "$OPENCLAW_BIN" ]] || {
  echo "openclaw binary not found" >&2
  exit 1
}
```

Rules:

- Call `"$OPENCLAW_BIN"`, not `openclaw` via a mocked `PATH` entry.
- Do not place a wrapper script named `openclaw` ahead of the real binary.
- If tests need a configurable binary path, it must still point at a real production `openclaw` install.

## Environment Setup

Each test gets a fresh temp root, for example:

```bash
TEST_ROOT="$(mktemp -d)"
TEST_HOME="$TEST_ROOT/openclaw-home"
mkdir -p "$TEST_HOME"
printf '{}\n' > "$TEST_HOME/openclaw.json"
```

Export:

```bash
export OPENCLAW_HOME="$TEST_HOME"
export OPENCLAW_CONFIG_PATH="$TEST_HOME/openclaw.json"
```

Create `"$TEST_ROOT/.env"` with dummy values for all required env vars used by production patches:

```dotenv
ANTHROPIC_API_KEY=dummy-anthropic
OPENAI_API_KEY=dummy-openai
GEMINI_API_KEY=dummy-gemini
DISCORD_TOKEN=dummy-discord-token
DISCORD_OWNER_ID=dummy-discord-owner
DISCORD_GUILD_ID=dummy-discord-guild
TELEGRAM_BOT_TOKEN=dummy-telegram-token
TELEGRAM_OWNER_ID=dummy-telegram-owner
SIGNAL_PHONE_NUMBER=+15555550123
SLACK_BOT_TOKEN=dummy-slack-bot
SLACK_APP_TOKEN=dummy-slack-app
SLACK_OWNER_USER_ID=dummy-slack-owner
```

Notes:

- The old `PERPLEXITY_API_KEY` dummy should be removed from the integration harness. The production `web-search.yaml` patch now requires `GEMINI_API_KEY`.
- The test should `cd "$TEST_ROOT"` before any `openclaw` command or gateway process starts.
- All test-created logs should live under `"$TEST_ROOT"`.

## Ephemeral Gateway

Some steps need a live gateway, specifically:

- `cron` fixture tests (`cron add`, `cron list`)
- `restart` fixture tests
- the full production integration test, if we want to validate gateway-facing behavior in the same environment

Start a real gateway process using the temp home and temp cwd:

```bash
export OPENCLAW_GATEWAY_URL="ws://127.0.0.1:18999"

cd "$TEST_ROOT"
"$OPENCLAW_BIN" gateway run \
  --port 18999 \
  --bind loopback \
  --auth none \
  --allow-unconfigured \
  >"$TEST_ROOT/gateway.log" 2>&1 &
GATEWAY_PID=$!
```

Readiness check:

- Retry `"$OPENCLAW_BIN" cron list --json` with `OPENCLAW_GATEWAY_URL=ws://127.0.0.1:18999` until it succeeds or a timeout is hit.
- Do not assume the gateway is ready immediately after fork.

Recommended wait loop:

```bash
for _ in $(seq 1 50); do
  if OPENCLAW_GATEWAY_URL="$OPENCLAW_GATEWAY_URL" \
     "$OPENCLAW_BIN" cron list --json >/dev/null 2>&1; then
    break
  fi
  sleep 0.2
done
```

If the loop times out, print `gateway.log` and fail the test.

## Port Isolation

Use port `18999` for the ephemeral test gateway.

Rationale:

- the normal local gateway port is `18789`,
- `18999` avoids accidental collision with a user’s real gateway,
- `127.0.0.1` + `--bind loopback` keeps the test gateway inaccessible from the network,
- `--auth none` keeps the gateway easy to interrogate from the isolated test process only.

Dummy channel tokens may still cause connection attempts during startup once plugins are enabled, but those attempts should fail harmlessly because:

- the credentials are fake,
- the instance is isolated to a temp config,
- the gateway is bound to loopback only,
- the test never points to the user’s real config or gateway URL.

The suite should not fail merely because plugin startup logs auth errors with dummy credentials.

## Test Harness Structure

Keep two top-level entrypoints:

- `shared/patches/tests/run-tests.sh` for fixture-driven step coverage
- `shared/patches/tests/integration-test.sh` for the full production patch set

Recommended helper flow:

### `setup()`

Responsibilities:

1. Create temp root and temp OpenClaw home.
2. Seed `openclaw.json` with `{}`.
3. Create temp `.env` with dummy values.
4. Export `OPENCLAW_HOME`, `OPENCLAW_CONFIG_PATH`, and optionally `OPENCLAW_GATEWAY_URL`.
5. Copy fixture assets when running a fixture test.
6. `cd` into the temp root.
7. Start the ephemeral gateway.
8. Wait for readiness.

Baseline flow per test:

```text
setup -> load fixture(s) -> apply -> assert -> teardown
```

### `teardown()`

Responsibilities:

1. Kill the gateway process or process group.
2. Wait briefly for shutdown.
3. Delete the temp root with `rm -rf`.
4. Unset exported test env vars.

The teardown must tolerate restart tests, where the gateway PID may change.

### Integration test flow

```text
setup -> apply all production patches -> validate config/state -> re-apply -> assert idempotency -> teardown
```

## Patch Roots

There are two distinct patch roots in the rewritten suite.

### Fixture tests

For tests under `run-tests.sh`, create a temp patches repo with this shape:

- `patches/`
- `files/`
- `skills/`
- `extensions/`

Copy in only the requested fixture patch plus its needed assets, then export:

```bash
export OPENCLAW_PATCHES_DIR="$TEST_PATCH_ROOT"
```

This preserves the current “single fixture patch at a time” testing model.

### Production integration test

For `integration-test.sh`, point `OPENCLAW_PATCHES_DIR` at the real repo path:

```bash
export OPENCLAW_PATCHES_DIR="$REPO_ROOT/shared/patches"
```

This must apply the actual YAML files from `shared/patches/patches/`.

## Assertions

### Config-backed steps

Assert by reading the real `"$OPENCLAW_CONFIG_PATH"` with `jq`.

Examples:

- `jq -e '.models.mode == "merge"' "$OPENCLAW_CONFIG_PATH"`
- `jq -e '.plugins.entries.discord.enabled == true' "$OPENCLAW_CONFIG_PATH"`
- `jq -e '.skills.load.extraDirs | index("~/.agents/skills") != null' "$OPENCLAW_CONFIG_PATH"`

Do not assert by grepping a mock call log.

### Cron-backed steps

Assert against the live gateway via the real CLI:

```bash
OPENCLAW_GATEWAY_URL="$OPENCLAW_GATEWAY_URL" \
  "$OPENCLAW_BIN" cron list --json | jq ...
```

Required checks:

- the job exists after `cron add`,
- expected fields are present,
- rerunning the same patch does not create a duplicate,
- the second apply reports `0 applied`.

### File / mkdir / exec / skill steps

Assert directly on the temp filesystem:

- files exist,
- directories exist,
- file content matches,
- marker-based append remains single-copy,
- skill files exist under `"$OPENCLAW_HOME/skills/..."`.

### Plugin steps

Assert on the real config file:

- `plugins.entries.<id>.enabled == true`
- any related channel config written by the same patch exists and has expected values

### Extension steps

Assert both:

- files exist under `"$OPENCLAW_HOME/extensions/<name>/"`
- config reflects enablement when `enable: true`

For fixture `test-extension-step.yaml` with `enable: false`, assert only install side effects:

- extension files exist,
- plugin is not enabled in config.

### Idempotency

For both fixture and integration cases:

1. Apply once and assert the intended state exists.
2. Apply again without changing the temp home.
3. Assert the summary contains `0 applied`.
4. Assert state has not duplicated:
   - array entries remain deduped,
   - append-marker content appears once,
   - cron list still shows one job,
   - `patches/applied.json` count is unchanged.

## Fixture Coverage Plan

`run-tests.sh` should keep the existing behavioral coverage, but rewrite the CLI-backed tests to be truly end-to-end.

### Keep as mostly-is, but under isolated temp homes

- file content file
- file inline
- file append
- file append with marker
- file append marker idempotent
- mkdir
- skill
- exec
- target filter match/skip
- chronological ordering
- requires missing/satisfied
- docs/regression checks (`config_patch`, `merge_file`, stale docs references)

These already test actual filesystem behavior and only need environment cleanup tightening.

### Rewrite to use real `openclaw`

- `config_set`
- `config_append`
- `plugin_enable`
- `cron`
- `restart`
- `extension`
- full multi-step patch if it includes CLI-backed steps in the future

### Special cases

- `openclaw_update`
- `clawhub` (if/when a fixture is added)

These need explicit policy, described below.

## Special Handling

### `openclaw_update`

Problem:

- `openclaw update` targets the installed CLI, not the temp `OPENCLAW_HOME`.
- Running it in the default suite would mutate the developer or CI machine’s toolchain.

Policy:

- Do not run `openclaw_update` in the default automated suite.
- Move it to an explicit opt-in test path, for example gated by `RUN_OPENCLAW_UPDATE_TESTS=1`.
- Only run that test in a disposable environment where updating the global install is acceptable.

What to document in the test itself:

- it is a manual or CI-only smoke test,
- it uses the real binary,
- it is skipped by default for safety,
- no mock replacement is used.

### `restart` with a foreground gateway

Problem:

- the test harness starts a foreground `openclaw gateway run` process in the background,
- `openclaw gateway restart` may replace that process, reconnect to it, or behave as a best-effort restart request,
- `exec_step_restart` is intentionally non-fatal (`openclaw gateway restart || true`).

Policy:

- Treat restart as an availability test, not a PID-equality test.
- Before applying the patch, confirm the gateway responds.
- Apply the restart patch using the real CLI.
- Afterward, wait until `cron list --json` succeeds again against `ws://127.0.0.1:18999`.
- Pass if the patch completes and the gateway is reachable again.

Teardown requirement:

- kill by process group or by port listener, not only by the original PID, because restart may replace the process.

### `clawhub install`

Problem:

- it needs network access and registry availability,
- it is not represented in the current production patch set,
- a no-network environment should not fail the default suite.

Policy:

- keep `clawhub` out of the default offline suite,
- add a separate networked test entrypoint later if needed,
- gate it with something like `RUN_NETWORK_TESTS=1`,
- still use the real `clawhub` CLI when enabled.

## Integration Test Requirements

`shared/patches/tests/integration-test.sh` should:

1. create one temp OpenClaw home,
2. seed `openclaw.json` with `{}`,
3. write dummy `.env` values including `GEMINI_API_KEY`,
4. `cd` into the temp root,
5. start the ephemeral gateway on `18999`,
6. set `OPENCLAW_PATCHES_DIR` to `shared/patches`,
7. run `openclaw-patch apply -d "$DEPLOYMENT"`,
8. validate the resulting `openclaw.json` with `jq`,
9. validate plugin and extension side effects,
10. re-run apply and assert idempotency,
11. tear everything down.

### Required production assertions

At minimum, keep assertions for these patch outcomes:

- `agent-defaults`
- `memory-config`
- `session-config`
- `agent-collaboration`
- `agent-permissions`
- `model-providers`
- `discord-channel`
- `telegram-channel`
- `signal-channel`
- `slack-channel`
- `skills-config`
- `browser-config`
- `security-config`
- `audio-transcription`
- `inject-datetime`
- `web-search`

Concrete examples:

- `.agents.defaults.model.primary == "anthropic/claude-opus-4-6"`
- `.memory.backend == "builtin"`
- `.hooks.internal.enabled == true`
- `.tools.exec.security == "full"`
- `.tools.sessions.visibility == "all"`
- `.models.mode == "merge"`
- `.plugins.entries.discord.enabled == true`
- `.plugins.entries.telegram.enabled == true`
- `.plugins.entries.signal.enabled == true`
- `.plugins.entries.slack.enabled == true`
- `.browser.headless == false`
- `.discovery.wideArea.enabled == false`
- `.discovery.mdns.mode == "minimal"`
- `.tools.media.audio.enabled == true`
- `.tools.web.search.provider == "gemini"`
- `"$OPENCLAW_HOME/extensions/inject-datetime/openclaw.plugin.json"` exists

## Stale Assertion Bug

The current integration test is stale in two places:

1. It asserts:

```jq
.tools.web.search.provider == "perplexity"
```

2. It seeds `PERPLEXITY_API_KEY`, but the production patch now requires `GEMINI_API_KEY`.

The rewrite must fix both:

- assert `provider == "gemini"`
- seed `GEMINI_API_KEY`
- stop relying on `PERPLEXITY_API_KEY` for the production web-search patch

## Environment Isolation Guarantees

The rewritten suite must guarantee all of the following:

- `OPENCLAW_HOME` points to a temp directory.
- `OPENCLAW_CONFIG_PATH` points to the temp `openclaw.json`.
- the working directory is the temp root, so dotenv reads the temp `.env`.
- the gateway runs on `127.0.0.1:18999`, not the user’s normal `18789` gateway.
- dummy credentials are used for all required env vars.
- `OPENCLAW_PATCHES_DIR` points either at a temp fixture patch root or the repo’s `shared/patches` root, never the user’s live workspace.
- teardown removes the temp root completely.

If those guarantees hold, real `openclaw` commands can be exercised without touching the user’s live config, credentials, plugins, gateway, or cron state.

## Suggested Implementation Notes

- Capture gateway stdout/stderr to `"$TEST_ROOT/gateway.log"` for debugging.
- Capture patch CLI output to temp log files when a test fails.
- Fail fast if `openclaw`, `jq`, or `bash` prerequisites are missing.
- Keep fixture names and assertions close to the existing suite to reduce review risk.
- Prefer one helper library sourced by both test entrypoints so setup/teardown behavior stays identical.

## Non-Goals

- rewriting `openclaw-patch` itself,
- changing patch manifest semantics,
- introducing a fake config schema bootstrap,
- hiding CLI behavior behind wrappers,
- making `openclaw_update` or `clawhub` run in unsafe default local test mode.

## Acceptance Criteria

The rewrite is complete when:

1. `run-tests.sh` contains no mock `openclaw` binary setup.
2. `integration-test.sh` contains no mock `openclaw` binary setup.
3. CLI-backed assertions are based on real CLI effects and the real temp `openclaw.json`.
4. cron tests query the live ephemeral gateway on `ws://127.0.0.1:18999`.
5. the integration test validates `gemini`, not `perplexity`.
6. all tests run against disposable temp homes and leave no state behind.

