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
├── files/                # File contents referenced by patches
│   ├── configs/          # JSON fragments for config_patch steps
│   ├── workspace/        # Workspace files (AGENTS.md, etc.)
│   └── cron/             # Cron job definitions (JSON)
├── skills/               # Skill directories copied to ~/.openclaw/skills/
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
- **Overwrites** existing files (no merge). For config merging, use `config_patch`.

### 2. `config_patch` — Deep-merge into openclaw.json

Applies a JSON deep-merge to `~/.openclaw/openclaw.json`. Uses `jq`'s `*` operator (`.[0] * .[1]`).

```yaml
- type: config_patch
  merge_file: configs/update-models.json  # relative to files/
```

Where `files/configs/update-models.json`:
```json
{
  "models": {
    "default": "anthropic/claude-sonnet-4-20250514"
  }
}
```

**Rules:**
- `merge_file` is relative to `files/` dir. Must be valid JSON.
- Deep merge: nested objects are merged recursively, scalars are overwritten, **arrays are replaced** (not appended — this differs from OpenClaw's `config.patch` which appends).
- Requires `jq` on the instance.
- **Never include secrets** (API keys, tokens). Those stay in `.env`.

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

Creates or updates a cron job via the OpenClaw gateway API.

```yaml
- type: cron
  name: daily-healthcheck
  job_file: cron/daily-healthcheck.json  # relative to files/
```

Where `files/cron/daily-healthcheck.json` is a full OpenClaw cron job definition:
```json
{
  "name": "daily-healthcheck",
  "schedule": { "kind": "cron", "expr": "0 9 * * *", "tz": "America/New_York" },
  "payload": { "kind": "agentTurn", "message": "Run healthcheck", "timeoutSeconds": 300 },
  "sessionTarget": "isolated",
  "delivery": { "mode": "announce" },
  "enabled": true
}
```

**Current gap (v0.1):** The CLI just writes the JSON file to `~/.openclaw/workspace/cron-jobs/`. It doesn't actually call the gateway API to register the job. This is a known limitation — the cron job must be manually registered or registered by a subsequent `exec` step.

**Target (v0.2):** Use `curl` to hit the gateway's cron API (`POST /api/cron/jobs`) to actually register/update the job. Requires the gateway to be running and accessible on localhost.

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

Updates the OpenClaw npm package.

```yaml
- type: openclaw_update
  version: latest  # or "1.2.3"
```

**Rules:**
- `version: latest` or omitted → `npm install -g openclaw`
- Specific version → `npm install -g openclaw@<version>`
- Should typically be followed by a `restart` step.
- **Note:** Mac mini uses `bun` not `npm`. Need platform detection or configurable package manager.

### 8. `restart` — Restart the OpenClaw gateway

```yaml
- type: restart
```

**Rules:**
- Tries `systemctl --user restart openclaw-gateway` first (Linux/systemd).
- Falls back to `openclaw gateway restart`.
- Non-fatal if restart fails (warns but doesn't stop the patch).

---

## Known Gotchas & Design Gaps

### YAML Parsing
The CLI uses a hand-rolled mini YAML parser (grep/sed). This works for simple key-value pairs but has real limitations:
- **Multi-line values** aren't supported (no `|` or `>` block scalars)
- **Nested objects** under steps can't be read (hence `merge_file` and `job_file` indirection)
- **Arrays** only work for the `targets` field and `clawhub.skills` (special-cased)

**Decision:** Keep the mini parser for v1. All complex content goes in external files referenced by `*_file` keys. This is actually a cleaner design anyway — YAML manifests stay small and readable, content lives in proper files.

If we ever need real YAML parsing: `yq` is the obvious choice, but it's an extra dependency. `python3 -c 'import yaml; ...'` is available on most systems.

### Cron Job Registration
The `cron` step currently just writes a JSON file. It doesn't register with the running gateway. Options:
1. **exec step chaining** — follow `cron` step with `exec` that curls the gateway API
2. **Built-in gateway API call** — the CLI calls `curl localhost:<port>/api/cron/jobs` directly
3. **OpenClaw CLI** — `openclaw cron add --file <path>` (if this exists or gets added)

**Decision for v1:** Option 1 (document the pattern). Option 2 for v1.1 once we know the gateway API shape reliably.

### Package Manager Detection
Mac mini uses `bun`, EC2 uses `npm`. The `openclaw_update` step hardcodes `npm install -g`.

**Decision:** Detect at runtime: if `bun` exists and openclaw was installed via bun, use `bun install -g`. Otherwise `npm install -g`. Check with `which openclaw` → resolve symlink → infer package manager.

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

- [ ] Create `patches/`, `files/configs/`, `files/workspace/`, `files/cron/`, `skills/`, `tests/fixtures/`, `docs/` directories
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
- [ ] **jq dependency check**: `exec_step_config_patch` calls `need_cmd jq` but other steps that need jq (like `is_applied`) don't. Add jq check at the start of `cmd_apply`.
- [ ] **Sed portability**: `sed -i.bak` works on macOS but the fallback JSON append in `mark_applied` is fragile. Since we already require `jq` for config_patch, just always require jq and remove the sed fallback.
- [ ] **Exit on step failure**: `exec_step` functions don't always return proper exit codes. Wrap each in a subshell or check `$?` explicitly.

**Verify:** Run `openclaw-patch validate` with no patches (should succeed). Run `openclaw-patch list` (should show empty list). Run `shellcheck scripts/openclaw-patch` — fix any errors.

### Task 3: Write the test suite
Create a test harness that exercises each step type in isolation.

- [ ] Create `tests/run-tests.sh` — a bash test runner
- [ ] Create `tests/fixtures/` with test patch manifests and supporting files:
  - `test-file-step.yaml` + `tests/fixtures/files/test-content.txt`
  - `test-config-patch.yaml` + `tests/fixtures/files/configs/test-merge.json`
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
