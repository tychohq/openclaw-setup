# openclaw-patch

Declarative patch system for OpenClaw deployments. Author patches centrally in `openclaw-setup`, then pull and apply them on any instance.

## Quick Start

```bash
# Work from the patch repo root
cd ~/projects/openclaw-setup/shared/patches

# On the author machine — create and edit a patch
./scripts/openclaw-patch new update-default-model
$EDITOR patches/update-default-model.yaml

# Validate, review, and publish
./scripts/openclaw-patch validate update-default-model
./scripts/openclaw-patch list
./scripts/openclaw-patch publish

# On any instance — pull and inspect pending work
cd ~/projects/openclaw-setup/shared/patches
./scripts/openclaw-patch pull
./scripts/openclaw-patch status --deployment opensesame

# Apply pending patches for that deployment
./scripts/openclaw-patch apply --deployment opensesame

# Or do both in one shot
./scripts/openclaw-patch sync --deployment opensesame
```

## CLI Reference

The script lives at `shared/patches/scripts/openclaw-patch`. In examples below, you can run it either as `./scripts/openclaw-patch ...` from `shared/patches/` or as `openclaw-patch ...` if it is on your `PATH`.

### `new <name>`

Creates a new patch scaffold at `patches/<name>.yaml` with a fresh `created` timestamp and commented examples for supported step types.

```bash
./scripts/openclaw-patch new browser-config
```

### `list`

Lists patches in chronological order and shows each patch's description, creation time, targets, optional `requires`, and whether it has already been applied on the current machine. The script also accepts `ls` as an alias.

```bash
./scripts/openclaw-patch list
```

### `validate [name]`

Validates all patch manifests, or a single patch if you pass its name without the `.yaml` suffix. Validation checks required top-level fields, referenced files in `files/`, referenced skill and extension directories, and whether each step type is known.

```bash
./scripts/openclaw-patch validate
./scripts/openclaw-patch validate browser-config
```

### `publish`

Runs `validate`, then stages changes, creates a git commit, and pushes the repo. This is the authoring workflow command for publishing patch updates to other machines.

```bash
./scripts/openclaw-patch publish
```

### `pull`

Runs a fast-forward `git pull --ff-only` in the patch repo to fetch the latest published patches.

```bash
./scripts/openclaw-patch pull
```

### `apply --deployment <name>`

Applies pending patches for a deployment. The command:

- skips patches already recorded in the local applied-state file
- skips patches whose `targets` do not match the deployment
- skips patches whose `requires` env vars are missing, and reports what is missing
- applies matching patches in ascending `created` order
- records success in `$OPENCLAW_HOME/patches/applied.json`

Use `--dry-run` to preview what would apply without making changes.

```bash
./scripts/openclaw-patch apply --deployment opensesame
./scripts/openclaw-patch apply -d mac-mini --dry-run
```

### `status --deployment <name>`

Shows applied and pending patches for one deployment, including any `requires` values attached to pending patches.

```bash
./scripts/openclaw-patch status --deployment opensesame
./scripts/openclaw-patch status -d mac-mini
```

### `sync --deployment <name>`

Runs `pull` followed by `apply` for the same deployment.

```bash
./scripts/openclaw-patch sync --deployment opensesame
```

### `diff --deployment <name>`

Dry-run view of `apply`. Internally this is equivalent to `apply --dry-run --deployment <name>`.

```bash
./scripts/openclaw-patch diff --deployment opensesame
```

## Environment

| Variable | Description |
|----------|-------------|
| `OPENCLAW_PATCHES_DIR` | Override the patch repo root. In this repo, that root is `~/projects/openclaw-setup/shared/patches`, not the top-level `openclaw-setup` directory. |
| `OPENCLAW_HOME` | Override the OpenClaw home directory. Defaults to `~/.openclaw`, and the patch state file lives at `$OPENCLAW_HOME/patches/applied.json`. |

Examples:

```bash
OPENCLAW_PATCHES_DIR=~/projects/openclaw-setup/shared/patches \
  openclaw-patch list

OPENCLAW_HOME=~/.openclaw-alt \
  ./scripts/openclaw-patch status --deployment mac-mini
```

## Patch Format

Patches are YAML manifests in `patches/`. Each patch has an ID, optional target filter, optional required env vars, and a list of steps:

```yaml
id: update-default-model
description: "Switch default model to claude-sonnet-4"
targets: ["*"]  # or ["opensesame", "mac-mini"]
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
| `targets` | recommended | Deployment filter. Use `["*"]` or omit it to match every deployment; use names like `opensesame` or `mac-mini` to scope a patch. |
| `created` | yes | ISO-8601 timestamp used to determine apply order. |
| `requires` | no | List of env vars that must already exist before the patch runs. Missing vars cause that patch to be skipped and reported. |
| `steps` | yes | Ordered list of step definitions to execute when the patch is applied. |

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
3. **State** is tracked per machine in `~/.openclaw/patches/applied.json` by default.
4. Patches are applied in chronological order based on `created`.
5. Already-applied patches are skipped, making the process idempotent.
6. `requires` are checked before running a patch, and missing env vars cause that patch to be skipped with a warning.

## Instance Setup

The patch source of truth lives inside the `openclaw-setup` repo at `shared/patches/`.

On a new instance:

```bash
git clone https://github.com/tychohq/openclaw-setup.git ~/projects/openclaw-setup
cd ~/projects/openclaw-setup/shared/patches

./scripts/openclaw-patch status --deployment mac-mini
./scripts/openclaw-patch sync --deployment mac-mini
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
- **Target filtering** lets you scope patches to specific deployments.
- **`requires` provides guardrails** so patches that depend on local env vars are skipped instead of partially applying.
- **`exec` steps** are explicit and auditable via git history.
