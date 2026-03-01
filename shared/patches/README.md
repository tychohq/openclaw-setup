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

Patches are YAML manifests in `patches/`. Each patch has an ID, optional target filter, and a list of steps:

```yaml
id: update-default-model
description: "Switch default model to claude-sonnet-4"
targets: ["*"]  # or ["opensesame", "mac-mini"]
created: 2026-02-27T10:00:00Z

steps:
  - type: config_patch
    merge:
      models:
        default: "anthropic/claude-sonnet-4-20250514"

  - type: restart
```

## Step Types

| Type | Description |
|------|-------------|
| `file` | Write a file to a path on the instance |
| `config_patch` | Deep-merge into `openclaw.json` |
| `skill` | Copy a skill directory to `~/.openclaw/skills/` |
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
scripts/           The openclaw-patch CLI
docs/              Detailed documentation
```

## Security

- **No secrets in patches.** Config patches merge — they add/override keys but never contain API keys or tokens.
- **Secrets stay in `.env`** on each instance and in `openclaw-deployments` (private repo).
- **Target filtering** lets you scope patches to specific deployments.
- **Exec steps** are opt-in and auditable via git history.
