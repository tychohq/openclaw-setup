# openclaw-setup

Setup scripts and configuration templates for deploying [OpenClaw](https://github.com/openclaw/openclaw) on new machines — macOS or AWS.

## Where to Start

| I want to... | Go to |
|---|---|
| Set up OpenClaw on a **Mac** | [macos/README.md](macos/README.md) |
| Deploy OpenClaw on **AWS** (EC2) | [aws/README.md](aws/README.md) |

Both paths get you from zero to a running OpenClaw instance with your AI providers, chat channels, and workspace configured.

## What You'll Need

Regardless of platform, you'll need:

- **At least one AI provider API key** — Anthropic, OpenAI, OpenRouter, or Gemini
- **At least one chat channel** — Discord bot token, Telegram bot token, or Slack tokens
- Optionally: Brave Search API key, additional provider keys

The setup guides walk you through where to get each of these.

## Repo Structure

```
openclaw-setup/
├── aws/              # AWS EC2 deployment (Terraform + setup wizard)
├── macos/            # macOS provisioning (Homebrew, apps, OpenClaw)
├── shared/           # Resources shared across platforms
│   ├── checklist/    # Deployment health check system
│   ├── config/       # Config and env templates
│   ├── cron-jobs/    # Starter cron job definitions
│   ├── patches/      # Declarative config patch system
│   ├── scripts/      # Setup, bootstrap, and audit scripts
│   ├── skills/       # Custom OpenClaw skills
│   └── workspace/    # Workspace starter files (SOUL.md, docs, tools, etc.)
├── web/              # Setup catalog frontend (browse patches, skills, cron jobs)
├── scripts/          # Build scripts (catalog index generation)
└── meta/             # Internal docs, PRDs, and project notes
```

## Config Patches

The **patch system** (`shared/patches/`) lets you manage OpenClaw configuration as declarative YAML manifests. Instead of SSHing into each instance to tweak config, you author patches once and apply them everywhere.

Each patch is a YAML file that declares what it changes:

```yaml
id: web-search
description: "Enable Brave web search"
targets: ["*"]
requires:
  - BRAVE_SEARCH_API_KEY
steps:
  - type: config_set
    path: web.provider
    value: "brave"
  - type: restart
```

**How it works:**

1. Patches live in `shared/patches/patches/` as YAML files
2. On any instance, pull the repo and run `openclaw-patch apply --deployment <your-deployment>`
3. Already-applied patches are skipped (idempotent)
4. Patches apply in chronological order by `created` timestamp
5. Target filtering lets you scope patches to specific deployments

**Available patches:** model providers, web search, browser config, memory, security, session settings, channel-specific configs (Discord, Telegram, Slack, Signal), agent defaults, and more.

See [shared/patches/README.md](shared/patches/README.md) for the full patch reference and step types.

## Health Checks

After setup, verify everything works with the deployment health check:

```bash
bash shared/checklist/checklist.sh
```

Checks gateway status, channels, CLI tools, disk space, credentials, and more. See [shared/checklist/README.md](shared/checklist/README.md).

## Safe Upgrades

This repo includes a wrapper-based upgrade flow for OpenClaw that runs **outside** the gateway process, writes timestamped logs/backups, verifies health, and rolls back on failure.

```bash
bash shared/scripts/openclaw-upgrade --dry-run
bash shared/scripts/openclaw-upgrade --channel stable
bash shared/scripts/openclaw-upgrade --channel stable --with-patches --deployment mac-mini
bash shared/scripts/openclaw-upgrade-timer install --platform macos --mode apply --channel stable
bash shared/scripts/openclaw-upgrade-timer install --platform linux --mode notify-only --channel beta
```

What it does:

- Uses `~/.openclaw/.upgrade-lock` to prevent overlapping runs
- Logs to `~/.openclaw/logs/upgrade-<timestamp>.log`
- Backs up state to `~/.openclaw/backups/upgrade-<timestamp>/`
- Runs `openclaw update --yes --no-restart --json`
- Restarts via `launchctl` or `systemctl --user`
- Polls `openclaw health --json`
- Verifies cron jobs and skills are still present
- Restores config and rolls back the version if post-update checks fail
- Optionally runs `openclaw-patch sync --deployment <name>` after a healthy upgrade

Timer support:

- `shared/scripts/openclaw-upgrade-timer` installs launchd or systemd user timers
- Templates live in `shared/templates/launchd/` and `shared/templates/systemd/`
- Timer install enforces `update.auto.enabled=false` to avoid overlapping auto-updates

Optional defaults live in `shared/config/openclaw-upgrade.env.template`, which you can copy to `~/.openclaw/openclaw-upgrade.env`.

Run the shell tests with:

```bash
bash shared/scripts/tests/run-tests.sh
```

## License

MIT
