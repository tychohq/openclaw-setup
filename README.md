# openclaw-setup

Everything you need to get [OpenClaw](https://github.com/openclaw/openclaw) running — on a Mac or on AWS. Clone this repo, fill in your API keys, and follow the guide for your platform.

## Choose Your Path

| Platform | What it does | Guide |
|----------|-------------|-------|
| **macOS** | Sets up a Mac from scratch — Homebrew, apps, CLI tools, and OpenClaw | [macos/README.md](macos/README.md) |
| **AWS** | Deploys OpenClaw to an EC2 instance via Terraform | [aws/README.md](aws/README.md) |

## What You Need

Before you start, you'll need:

1. **At least one AI provider API key** — [Anthropic](https://console.anthropic.com/), [OpenAI](https://platform.openai.com/api-keys), or [OpenRouter](https://openrouter.ai/keys)
2. **At least one chat channel** — [Discord bot token](https://discord.com/developers/applications), [Telegram bot](https://t.me/BotFather), or [Slack app](https://api.slack.com/apps)

Both setup paths use the same config templates in [`shared/config/`](shared/config/):

| File | What goes in it |
|------|----------------|
| `openclaw-config.template.json` | Channel config, model settings, gateway options |
| `openclaw-env.template` | API keys and tokens (`ANTHROPIC_API_KEY`, `DISCORD_TOKEN`, etc.) |
| `openclaw-auth-profiles.template.json` | Provider auth profiles (API keys per provider) |

Copy these templates, fill in your values, and point the setup script at them. Both the macOS and AWS guides walk you through this. The filled-in files are gitignored and never committed.

## Patches

After your instance is running, you can layer on features using the **patch system** in [`shared/patches/`](shared/patches/README.md).

Patches are small YAML manifests that configure OpenClaw features — things like web search, audio transcription, browser control, memory, and security hardening. Instead of manually editing `openclaw.json`, you apply patches:

```bash
# Pull the latest patches and apply them
cd ~/openclaw-setup
git pull
./shared/patches/scripts/openclaw-patch sync --deployment my-deployment
```

Each patch declares what it does, what env vars it needs, and which config keys it sets. Already-applied patches are skipped automatically. See the [patches README](shared/patches/README.md) for the full reference.

**Available patches:** agent-defaults, agent-collaboration, agent-permissions, audio-transcription, browser-config, discord-channel, inject-datetime, memory-config, model-providers, security-config, session-config, signal-channel, skills-config, slack-channel, telegram-channel, web-search.

## Repo Structure

```
openclaw-setup/
├── aws/                # AWS EC2 deployment (Terraform + setup wizard)
├── macos/              # macOS provisioning (Homebrew, apps, dotfiles, OpenClaw)
├── shared/
│   ├── checklist/      # Post-deploy health check scripts
│   ├── config/         # Config and env templates (start here)
│   ├── cron-jobs/      # Starter cron job definitions
│   ├── patches/        # Declarative patch system
│   ├── scripts/        # Setup, bootstrap, and audit scripts
│   ├── skills/         # Custom OpenClaw skills
│   └── workspace/      # Workspace starter files (SOUL.md, docs, tools)
├── web/                # Setup catalog frontend (browse patches, skills, cron jobs)
└── meta/               # Internal docs, PRDs, and project notes
```

## License

MIT
