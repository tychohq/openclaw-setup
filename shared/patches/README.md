# openclaw-patch

Declarative patch system for OpenClaw. Author patches centrally in `openclaw-setup`, then pull and apply them on any instance.

## Quick Start

```bash
# Clone the repo (or pull if you already have it)
git clone https://github.com/openclaw/openclaw-setup.git ~/projects/openclaw-setup

# Apply all pending patches
cd ~/projects/openclaw-setup/shared/patches
./scripts/openclaw-patch apply

# Or pull latest + apply in one shot
./scripts/openclaw-patch sync
```

## CLI Reference

The script lives at `shared/patches/scripts/openclaw-patch`. In examples below, you can run it either as `./scripts/openclaw-patch ...` from `shared/patches/` or as `openclaw-patch ...` if it is on your `PATH`.

### `new <name>`

Creates a new patch scaffold at `patches/<name>.yaml` with a fresh `created` timestamp and commented examples for supported step types.

```bash
openclaw-patch new browser-config
```

### `list`

Lists patches in chronological order and shows each patch's description, creation time, targets, and whether it has already been applied on the current machine. Also accepts `ls` as an alias.

```bash
openclaw-patch list
```

### `validate [name]`

Validates all patch manifests, or a single patch if you pass its name without the `.yaml` suffix. Checks required top-level fields, referenced files in `files/`, referenced skill and extension directories, and whether each step type is known.

```bash
openclaw-patch validate
openclaw-patch validate browser-config
```

### `publish`

Runs `validate`, then stages changes, creates a git commit, and pushes the repo. This is the authoring workflow command for publishing patch updates.

```bash
openclaw-patch publish
```

### `pull`

Runs a fast-forward `git pull --ff-only` to fetch the latest published patches.

```bash
openclaw-patch pull
```

### `apply`

Applies pending patches. The command:

- skips patches already recorded in the local applied-state file
- skips patches whose `requires` env vars are missing, and reports what is missing
- applies matching patches in ascending `created` order
- records success in `$OPENCLAW_HOME/patches/applied.json`

Use `--dry-run` to preview what would apply without making changes.

```bash
openclaw-patch apply
openclaw-patch apply --dry-run
```

### `status`

Shows applied and pending patches, including any `requires` values attached to pending patches.

```bash
openclaw-patch status
```

### `sync`

Runs `pull` followed by `apply`.

```bash
openclaw-patch sync
```

### `diff`

Dry-run view of `apply`. Equivalent to `apply --dry-run`.

```bash
openclaw-patch diff
```

## Environment

| Variable | Description |
|----------|-------------|
| `OPENCLAW_PATCHES_DIR` | Override the patch repo root. Default: auto-detected from the script location. |
| `OPENCLAW_HOME` | Override the OpenClaw home directory. Defaults to `~/.openclaw`. Patch state lives at `$OPENCLAW_HOME/patches/applied.json`. |

## Patch Format

Patches are YAML manifests in `patches/`. Each patch has an ID, optional required env vars, and a list of steps:

```yaml
id: update-default-model
description: "Switch default model to claude-sonnet-4"
created: 2026-02-27T10:00:00Z

requires:
  - ANTHROPIC_API_KEY

steps:
  - type: config_set
    path: models.default
    value: "anthropic/claude-sonnet-4-20250514"

  - type: restart
```

## Manifest Fields

| Field | Required? | Description |
|-------|-----------|-------------|
| `id` | yes | Unique patch identifier. |
| `description` | recommended | Human-readable description shown in `list`, `status`, and `apply` output. |
| `created` | yes | ISO-8601 timestamp used to determine apply order. |
| `requires` | no | List of env vars that must already exist before the patch runs. Missing vars cause that patch to be skipped and reported. |
| `steps` | yes | Ordered list of step definitions to execute when the patch is applied. |
| `targets` | no | Deployment filter for multi-machine setups. See [Targeting](#targeting-advanced) below. |

## Step Types

| Type | Description |
|------|-------------|
| `file` | Write a file to disk from `content_file` or inline `content`. Supports `mode: overwrite` and `mode: append`, plus optional `marker`-based idempotency for appends. |
| `config_set` | Set a single OpenClaw config value via `openclaw config set`, with environment-variable expansion in the path and value. |
| `config_append` | Read an existing JSON array config value, prepend new entries, dedupe with `jq`, and write the merged array back. |
| `plugin_enable` | Enable an already-installed OpenClaw plugin by id. |
| `mkdir` | Create one or more directories. |
| `skill` | Copy a skill directory from `skills/` into `$OPENCLAW_HOME/skills/<name>`. |
| `extension` | Install an extension from `extensions/` with `openclaw plugins install`, then optionally enable or disable it. |
| `clawhub` | Install one or more skills from ClawHub. |
| `cron` | Register a cron job with `openclaw cron add` if a job with the same name does not already exist. |
| `exec` | Run an arbitrary shell command. |
| `openclaw_update` | Run `openclaw update --yes`, optionally pinned to a specific version tag. |
| `restart` | Restart the OpenClaw gateway via the CLI, with a `systemctl --user` fallback when available. |

See `docs/step-reference.md` for full step details.

## How It Works

1. **Authors** create patch YAML manifests and supporting files in this repo.
2. **Instances** pull updates from `openclaw-setup` and run `openclaw-patch apply`.
3. **State** is tracked per machine in `~/.openclaw/patches/applied.json`.
4. Patches are applied in chronological order based on `created`.
5. Already-applied patches are skipped, making the process idempotent.
6. `requires` are checked before running a patch, and missing env vars cause that patch to be skipped with a warning.

## Instance Setup

The patch source of truth lives inside the `openclaw-setup` repo at `shared/patches/`.

On a new instance:

```bash
git clone https://github.com/openclaw/openclaw-setup.git ~/projects/openclaw-setup
cd ~/projects/openclaw-setup/shared/patches

./scripts/openclaw-patch status
./scripts/openclaw-patch sync
```

If you invoke `openclaw-patch` from outside `shared/patches/`, set `OPENCLAW_PATCHES_DIR=~/projects/openclaw-setup/shared/patches` so the CLI can find `patches/`, `files/`, `skills/`, and `extensions/`.

## Directory Structure

```
patches/           Patch manifests (YAML)
files/             File contents referenced by file steps
  workspace/       Workspace files (AGENTS.md, etc.)
  cron/            Cron job definitions (JSON)
skills/            Skill directories referenced by patches
extensions/        Plugin extension directories referenced by patches
scripts/           The openclaw-patch CLI
tests/             Test suite
docs/              Detailed documentation
```

## Security

- **No secrets in patches.** Keep API keys, tokens, and other secrets out of manifests and referenced files.
- **Secrets stay local.** Store secrets in `.env`, secret managers, or deployment-specific setup outside this repo.
- **`requires` provides guardrails** so patches that depend on local env vars are skipped instead of partially applying.
- **`exec` steps** are explicit and auditable via git history.

## Targeting (Advanced)

If you manage multiple machines (e.g. a desktop and a cloud server), you can scope patches to specific deployments using the `targets` field and `--deployment` flag:

```yaml
# Only apply on a specific deployment
id: desktop-browser
targets: ["my-desktop"]
# ...
```

```bash
# Apply only patches that target "my-desktop"
openclaw-patch apply --deployment my-desktop

# Check status for a specific deployment
openclaw-patch status -d my-desktop
```

When `--deployment` is omitted (the default), all patches with `targets: ["*"]` or no `targets` field are applied. When `--deployment` is specified, patches must either target `"*"` or include the specified deployment name.
