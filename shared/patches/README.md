# openclaw-patches

Declarative patch system for OpenClaw deployments. Author patches centrally, pull and apply them on any instance.

## Quick Start

```bash
# On the author machine — create a patch
./scripts/openclaw-patch new "update-default-model"

# Edit the patch manifest
vim patches/update-default-model.yaml

# Validate and push
./scripts/openclaw-patch publish

# On any instance — pull and apply
./scripts/openclaw-patch pull
./scripts/openclaw-patch apply --deployment my-deployment

# Or one-shot
./scripts/openclaw-patch sync --deployment my-deployment
```

## Patch Format

Patches are YAML manifests in `patches/`. Each patch has an ID, optional target filter, required env vars, and a list of steps:

```yaml
id: update-default-model
description: "Switch default model to claude-sonnet-4"
targets: ["*"]  # or ["opensesame", "mac-mini"]
created: 2026-02-27T10:00:00Z

requires:        # env vars that must be set before applying
  - ANTHROPIC_API_KEY

steps:
  - type: config_set
    path: models.default
    value: "anthropic/claude-sonnet-4-20250514"

  - type: restart
```

## Manifest Fields

| Field | Required | Description |
|-------|----------|-------------|
| `id` | yes | Unique patch identifier |
| `description` | yes | Human-readable description |
| `targets` | yes | Deployment filter (`["*"]` = all) |
| `created` | yes | ISO-8601 timestamp (determines apply order) |
| `requires` | no | List of env vars that must be set for this patch to be operational. These are runtime dependencies (e.g. tokens, owner IDs) — the apply script checks they exist before running steps and fails fast if any are missing. The vars may be consumed by OpenClaw at runtime rather than interpolated into the patch JSON directly. |
| `steps` | yes | Ordered list of steps to execute |

## Step Types

| Type | Description |
|------|-------------|
| `file` | Write a file to a path on the instance |
| `config_set` | Set a single config field via CLI |
| `config_append` | Append values to a config array (deduped) |
| `plugin_enable` | Enable an OpenClaw plugin by id |
| `mkdir` | Create directories |
| `skill` | Copy a skill directory to `~/.openclaw/skills/` |
| `extension` | Install a plugin extension to `~/.openclaw/extensions/` |
| `clawhub` | Install/update ClawHub skills |
| `cron` | Create or update a cron job |
| `exec` | Run a shell command |
| `openclaw_update` | Update the OpenClaw npm package |
| `restart` | Restart the OpenClaw gateway |

See [docs/step-reference.md](docs/step-reference.md) for full details.

## How It Works

1. **Author** creates patch YAML manifests and pushes to this repo
2. **Instances** pull the repo (via git clone/pull) and run `openclaw-patch apply`
3. **State** is tracked in `~/.openclaw/patches/applied.json` on each instance
4. Patches are applied in chronological order (by `created` timestamp)
5. Already-applied patches are skipped (idempotent)
6. `requires` are checked before any steps run — missing vars = immediate failure with instructions

## Instance Setup

On a new instance, one-time:

```bash
git clone https://github.com/tychohq/openclaw-patches.git ~/openclaw-patches
```

Then either run manually or set up a cron job for periodic sync.

## Directory Structure

```
patches/           Patch manifests (YAML)
files/             File contents referenced by patches
skills/            Skill directories referenced by patches
extensions/        Plugin extension directories referenced by patches
scripts/           The openclaw-patch CLI
docs/              Detailed documentation
```

## Security

- **No secrets in patches.** Config patches merge — they add/override keys but never contain API keys or tokens.
- **Secrets stay in `.env`** on each instance and in `openclaw-deployments` (private repo).
- **Target filtering** lets you scope patches to specific deployments.
- **Exec steps** are opt-in and auditable via git history.
