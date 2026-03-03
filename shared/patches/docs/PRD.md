# OpenClaw Patches — PRD

## Context

OpenClaw deployments are proliferating. Today there's the Mac mini (primary) and OpenSesame (EC2 in us-west-2 via SSM). More are coming. Every deployment needs the same config patches, skills, workspace files, cron jobs, and OpenClaw version — but each has its own secrets and environment.

**openclaw-patches** is a declarative patch system: author patches centrally, push to git, instances pull and apply. Think fleet management for OpenClaw.

The CLI (`scripts/openclaw-patch`) is roughed in with all 8 step types, but hasn't been tested end-to-end. This PRD covers hardening the CLI, fixing known design gaps, building the supporting infrastructure (directories, docs, tests), and creating the first real patches.

### Repo: `~/projects/openclaw-patches`
### GitHub: `github.com/tychohq/openclaw-patches`

---

## Design Principles

1. **Declarative** — patches describe desired state, not imperative scripts
2. **Idempotent** — re-applying = no-op (tracked in `~/.openclaw/patches/applied.json`)
3. **Pull-based** — instances pull from git; no push/webhook infrastructure needed
4. **No secrets in transit** — patches merge/override config; secrets stay in each instance's `.env`
5. **Auditable** — git history = full changelog of what changed and when
6. **Targetable** — patches scope to specific deployments or `*` for all
7. **Chronological** — applied in `created` timestamp order

---

## Architecture

```
Author (Mac mini)                    Instance (any)
─────────────────                    ──────────────
openclaw-patch new "foo"             openclaw-patch pull
  → patches/foo.yaml                   → git pull --ff-only
  → files/foo-config.json             openclaw-patch apply -d opensesame
openclaw-patch publish                 → parse YAML
  → validate + commit + push           → filter by target
                                       → execute steps in order
                                       → mark applied
```

### Directory Structure

```
openclaw-patches/
├── patches/              # YAML manifests (one per patch)
├── files/                # File contents referenced by file steps
│   ├── workspace/        # Workspace files (AGENTS.md, etc.)
│   └── cron/             # Cron job definitions (JSON)
├── skills/               # Skill directories copied to ~/.openclaw/skills/
├── extensions/           # Plugin extension directories
├── scripts/
│   └── openclaw-patch    # The CLI
├── tests/                # Test suite
│   ├── fixtures/         # Test patch manifests + files
│   └── run-tests.sh      # Test runner
├── docs/
│   ├── PRD.md            # This file
│   └── step-reference.md # Detailed step type docs
└── README.md
```

### State Tracking

Each instance maintains `~/.openclaw/patches/applied.json`:

```json
{
  "update-default-model": {
    "applied_at": "2026-02-27T15:30:00Z"
  },
  "add-weather-skill": {
    "applied_at": "2026-02-27T15:30:01Z"
  }
}
```

---

## Step Types — Detailed Spec

### 1. `file` — Write a file

Write content to any path on the instance. Supports inline content (short strings) or external file references (anything multi-line).

```yaml
- type: file
  path: ~/.openclaw/workspace/AGENTS.md
  content_file: workspace/AGENTS.md  # relative to files/
```

```yaml
- type: file
  path: ~/.openclaw/workspace/config/example.txt
  content: "single line content"
```

**Rules:**
- `path` is required. `~` expands to `$HOME`.
- Exactly one of `content_file` or `content` is required.
- `content_file` is relative to `files/` dir in the repo.
- Parent directories are created automatically.
- **Overwrites** existing files (no merge). For config changes, use `config_set` or `config_append`.

### 2. `config_set` — Set a single config field

Sets a single field in `~/.openclaw/openclaw.json` via `openclaw config set`.

```yaml
- type: config_set
  path: models.default
  value: "anthropic/claude-sonnet-4-20250514"
```

**Rules:**
- `path` is a dot-separated config key (e.g. `models.default`).
- `value` can be a string or JSON object/array.
- Requires `openclaw` CLI on the instance.
- **Never include secrets** (API keys, tokens). Those stay in `.env`.

### 2b. `config_append` — Append values to a config array

Reads an existing config array, merges new values (deduped), and writes back via `openclaw config set`.

```yaml
- type: config_append
  path: skills.load.extraDirs
  value: '["~/.agents/skills"]'
```

**Rules:**
- `path` is a dot-separated config key pointing to an array.
- `value` must be a JSON array string.
- Reads existing array, merges, deduplicates with `jq unique`.
- Requires both `openclaw` and `jq` on the instance.
- Idempotent — running multiple times produces the same result.

### 2c. `plugin_enable` — Enable a plugin

Enables an OpenClaw plugin by id via `openclaw plugins enable`.

```yaml
- type: plugin_enable
  plugin: discord
```

**Rules:**
- `plugin` is the plugin identifier (e.g. `discord`, `telegram`, `slack`, `signal`).
- Requires `openclaw` CLI on the instance.
- Idempotent — enabling an already-enabled plugin is a no-op.

### 2d. `mkdir` — Create directories

Creates one or more directories.

```yaml
- type: mkdir
  paths:
    - ~/.openclaw/workspace/memory/daily
    - ~/.openclaw/workspace/research
```

**Rules:**
- `paths` is required. `~` expands to `$HOME`.
- Creates parent directories automatically (`mkdir -p`).
- Idempotent — no error if directory already exists.

### 3. `skill` — Install a custom skill

Copies a skill directory from the repo into `~/.openclaw/skills/`.

```yaml
- type: skill
  name: my-custom-skill
  # Optional: source_dir if repo dir name differs from skill name
  # source_dir: my-custom-skill-v2
```

**Rules:**
- Source directory must exist in `skills/` in the repo.
- Destination is `~/.openclaw/skills/<name>/`.
- Full copy (`cp -r`) — replaces existing skill entirely.

### 3b. `extension` — Install a plugin extension

Copies a plugin extension directory from the repo into `~/.openclaw/extensions/` and optionally enables it.

```yaml
- type: extension
  name: inject-datetime
  enable: true
```

**Rules:**
- Source directory must exist in `extensions/` in the repo.
- Destination is `~/.openclaw/extensions/<name>/`.
- `enable` defaults to `true`. When enabled, calls `openclaw plugins enable <name>`.
- Requires gateway restart for the extension to take effect.

### 4. `clawhub` — Install/update ClawHub skills

Installs or updates skills from the public ClawHub registry.

```yaml
- type: clawhub
  skills:
    - "weather@latest"
    - "github@2.1.0"
```

**Rules:**
- Requires `clawhub` CLI on the instance.
- Each skill string follows ClawHub's `name@version` format.
- Failures on individual skills are warnings (non-fatal), logged but don't stop the patch.

### 5. `cron` — Register a cron job

Registers a cron job via `openclaw cron add`. Idempotent — skips if a job with the same name already exists.

```yaml
- type: cron
  name: daily-healthcheck
  schedule: "0 9 * * *"
  tz: America/New_York
  session: isolated
  message: "Run healthcheck"
  timeout_seconds: 300
  announce: true
```

**Rules:**
- All cron fields are declared inline in the YAML manifest (no external JSON file).
- `name`, `schedule`, and `message` are required; other fields are optional.
- Checks `openclaw cron list --json` first — skips if job name already exists.
- Requires `openclaw` CLI on the instance.

### 6. `exec` — Run a shell command

Escape hatch for anything the other step types can't handle.

```yaml
- type: exec
  command: "bun install -g openclaw-helper@latest"
```

**Rules:**
- Command runs via `eval` in the instance's shell.
- Use sparingly — prefer declarative step types.
- Commands should be idempotent (safe to re-run).
- No interactive commands (stdin is not available).
- Failures are fatal (stop the patch).

### 7. `openclaw_update` — Update OpenClaw itself

Calls `openclaw update --yes` to update OpenClaw. The CLI handles bun/npm detection automatically.

```yaml
- type: openclaw_update
  version: latest  # or "1.2.3"
```

**Rules:**
- `version` defaults to `latest`. Specific version is passed as `--tag`.
- Requires `openclaw` CLI on the instance.
- Should typically be followed by a `restart` step.

### 8. `restart` — Restart the OpenClaw gateway

```yaml
- type: restart
```

**Rules:**
- Prefers `openclaw gateway restart`.
- Falls back to `systemctl --user restart openclaw-gateway` if `openclaw` binary not available.
- Non-fatal if restart fails (warns but doesn't stop the patch).

---

## Known Gotchas & Design Gaps

### YAML Parsing
The CLI uses a hand-rolled mini YAML parser (grep/sed). This works for simple key-value pairs but has real limitations:
- **Multi-line values** aren't supported (no `|` or `>` block scalars)
- **Nested objects** under steps can't be read (hence `job_file` indirection for cron steps)
- **Arrays** only work for the `targets` field and `clawhub.skills` (special-cased)

**Decision:** Keep the mini parser for v1. All complex content goes in external files referenced by `*_file` keys. This is actually a cleaner design anyway — YAML manifests stay small and readable, content lives in proper files.

If we ever need real YAML parsing: `yq` is the obvious choice, but it's an extra dependency. `python3 -c 'import yaml; ...'` is available on most systems.

### Cron Job Registration
Resolved. The `cron` step now uses `openclaw cron add` directly with inline fields (`--name`, `--cron`, `--message`, etc.). No external JSON files needed.

### Package Manager Detection
Resolved. The `openclaw_update` step now uses `openclaw update --yes`, which handles bun/npm detection internally.

### Transport: How `apply` Gets Triggered on Remote Instances
The CLI is designed to run locally on each instance. Getting it to run on remote instances:

| Instance | Transport | How |
|----------|-----------|-----|
| Mac mini | Local | Just run `openclaw-patch sync -d mac-mini` |
| OpenSesame (EC2) | SSM | `aws ssm send-command` with the sync command |
| Future instances | SSH / SSM / cron | Depends on connectivity |

**v1 approach:** Manual trigger. Author pushes patches, then runs the sync command on each instance (locally or via SSM).

**v1.1 approach:** Each instance has a cron job that runs `openclaw-patch sync -d <name>` periodically (every 15min or hourly). Self-healing fleet.

### Rollback
v1 has no rollback. Patches are forward-only. If a patch breaks something:
1. Author a new patch that reverts the change
2. Push and apply

This is intentional — rollback adds significant complexity and git already provides the audit trail. Revisit if this becomes painful.

---

## Tasks

### Task 1: Scaffold repo structure
Create the missing directories and placeholder files.

- [ ] Create `patches/`, `files/workspace/`, `files/cron/`, `skills/`, `tests/fixtures/`, `docs/` directories
- [ ] Add `.gitkeep` to empty dirs so git tracks them
- [ ] Create `docs/step-reference.md` with the step type documentation from this PRD
- [ ] Create a project `AGENTS.md` (`.agents/agents.md`) with repo-specific coding instructions
- [ ] Add `CLAUDE.md` with `Read .agents/agents.md` pointer

**Verify:** `tree` shows all directories. `docs/step-reference.md` exists and is complete.

### Task 2: Fix CLI bugs and edge cases
The current CLI has several issues that need fixing.

- [ ] **Package manager detection** in `exec_step_openclaw_update`: detect bun vs npm at runtime
  ```bash
  # If openclaw symlink resolves to a bun path, use bun
  if readlink "$(which openclaw)" 2>/dev/null | grep -q bun; then
    bun install -g openclaw
  else
    npm install -g openclaw
  fi
  ```
- [ ] **Step parsing robustness**: the `parse_steps` function strips 4+ spaces of indentation but this breaks if someone uses 2-space indent. Normalize to handle 2, 4, or tab indentation.
- [ ] **Empty targets handling**: `matches_target` uses `read -ra` which may produce an empty array. Ensure `[[ ${#targets[@]} -eq 0 ]]` returns true (match all) when targets field is omitted entirely.
- [ ] **jq dependency check**: `exec_step_config_append` calls `need_cmd jq` but other steps that need jq (like `is_applied`) don't. Add jq check at the start of `cmd_apply`.
- [ ] **Sed portability**: `sed -i.bak` works on macOS but the fallback JSON append in `mark_applied` is fragile. Since we already require `jq` for `config_append`, just always require jq and remove the sed fallback.
- [ ] **Exit on step failure**: `exec_step` functions don't always return proper exit codes. Wrap each in a subshell or check `$?` explicitly.

**Verify:** Run `openclaw-patch validate` with no patches (should succeed). Run `openclaw-patch list` (should show empty list). Run `shellcheck scripts/openclaw-patch` — fix any errors.

### Task 3: Write the test suite
Create a test harness that exercises each step type in isolation.

- [ ] Create `tests/run-tests.sh` — a bash test runner
- [ ] Create `tests/fixtures/` with test patch manifests and supporting files:
  - `test-file-step.yaml` + `tests/fixtures/files/test-content.txt`
  - `test-config-set.yaml` + `test-config-append.yaml`
  - `test-skill-step.yaml` + `tests/fixtures/skills/test-skill/SKILL.md`
  - `test-clawhub-step.yaml` (mock — just verify parsing, don't actually install)
  - `test-cron-step.yaml` + `tests/fixtures/files/cron/test-job.json`
  - `test-exec-step.yaml` (safe command like `echo "test"`)
  - `test-full-patch.yaml` — a patch with multiple step types
- [ ] Each test:
  1. Sets up a temp `OPENCLAW_HOME` and `OPENCLAW_PATCHES_DIR`
  2. Runs the step/patch against the temp environment
  3. Asserts the expected files/state exist
  4. Cleans up
- [ ] Test idempotency: apply the same patch twice, verify second run is a no-op
- [ ] Test target filtering: apply with wrong deployment name, verify skip
- [ ] Test chronological ordering: two patches with different `created` dates, verify order

**Verify:** `tests/run-tests.sh` passes. All tests green.

### Task 4: Write the first real patches
Create actual patches that we'll use to sync OpenSesame with the Mac mini's config.

- [ ] **Patch: `base-workspace-files`** — Syncs core workspace files to all instances
  - Step: `file` for SOUL.md, IDENTITY.md, USER.md (from current Mac mini workspace)
  - Targets: `["*"]`
  - Copy current files to `files/workspace/`

- [ ] **Patch: `base-agents-md`** — Syncs AGENTS.md (may differ per instance but good baseline)
  - Step: `file` for AGENTS.md
  - Targets: `["*"]`

- [ ] **Patch: `install-core-skills`** — Install standard ClawHub skills
  - Step: `clawhub` with the skills every instance should have
  - Targets: `["*"]`

**Verify:** `openclaw-patch list` shows all patches in chronological order. `openclaw-patch validate` passes. Dry-run apply: `openclaw-patch apply -d mac-mini --dry-run` shows the patches would apply.

### Task 5: Test end-to-end on Mac mini
Actually apply the real patches locally to verify the full flow.

- [ ] Run `openclaw-patch sync -d mac-mini` (pull + apply)
- [ ] Verify `~/.openclaw/patches/applied.json` has all patches marked
- [ ] Verify workspace files were written correctly (diff against originals)
- [ ] Run `openclaw-patch status -d mac-mini` — all patches show ✓
- [ ] Run `openclaw-patch sync -d mac-mini` again — verify "0 applied" (idempotent)
- [ ] Run `openclaw-patch diff -d opensesame` — verify it shows what OpenSesame would get

---

## Future Work (Not in v1)

- **Auto-sync cron:** Each instance runs `openclaw-patch sync` on a schedule
- **Cron step gateway integration:** Direct API calls to register cron jobs
- **Rollback:** `openclaw-patch rollback <patch-id>` (author a reversal patch automatically)
- **Patch dependencies:** `depends_on: [other-patch-id]` for ordering beyond timestamps
- **Diff preview:** Show actual file diffs before applying (not just patch names)
- **Notifications:** Post to Discord/Slack when patches are applied on an instance
- **Patch groups/bundles:** Apply multiple patches as an atomic unit
- **Instance registration:** Instances self-register with a central manifest
- **Terraform integration:** `openclaw-patches sync` as part of the Terraform apply workflow
