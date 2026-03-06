# macOS Setup

One command to go from a fresh Mac to a fully configured machine with OpenClaw running.

```bash
curl -fsSL mac.brennerspear.com | bash
```

Or clone and run directly:

```bash
git clone https://github.com/tychohq/openclaw-setup.git ~/projects/openclaw-setup
cd ~/projects/openclaw-setup/macos
./setup.sh
```

## What It Does

1. Installs Xcode Command Line Tools
2. Installs Homebrew
3. Installs CLI tools (fd, fzf, gh, tmux, uv, etc.)
4. Installs apps via Homebrew Cask (Slack, Discord, Arc, Cursor, 1Password, etc.)
5. Installs Bun + global packages (TypeScript, Vercel CLI, etc.)
6. Sets up Node.js via fnm
7. Optionally installs Rust, Prezto/Powerlevel10k
8. Applies macOS defaults (dock, Finder, dark mode, etc.)
9. Creates directory structure
10. Optionally installs and configures OpenClaw

Everything is **idempotent** — safe to run multiple times. It skips what's already installed and reports what changed.

## Setting Up OpenClaw

After the base machine setup, configure OpenClaw with your API keys and chat channels.

### What You Need

You need **three files**, all created from templates in `shared/config/`:

| File | Template | What goes in it |
|---|---|---|
| `openclaw-secrets.json` | `shared/config/openclaw-config.template.json` | Channel configs, model settings, gateway settings |
| `openclaw-secrets.env` | `shared/config/openclaw-env.template` | API keys and tokens (see below) |
| `openclaw-auth-profiles.json` | `shared/config/openclaw-auth-profiles.template.json` | Provider auth profiles (API keys per provider) |

```bash
# From the repo root:
cp shared/config/openclaw-config.template.json openclaw-secrets.json
cp shared/config/openclaw-env.template          openclaw-secrets.env
cp shared/config/openclaw-auth-profiles.template.json openclaw-auth-profiles.json
```

These files are gitignored and never committed.

### Required Environment Variables (`.env`)

At minimum, you need **one AI provider key** and **one channel token**:

```bash
# Pick at least one AI provider:
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
OPENROUTER_API_KEY=sk-or-...
GEMINI_API_KEY=AI...

# Pick at least one chat channel:
DISCORD_TOKEN=MTIz...          # Discord Developer Portal → Bot → Token
TELEGRAM_BOT_TOKEN=123456:AB...  # @BotFather → /newbot
SLACK_BOT_TOKEN=xoxb-...        # Slack app management
SLACK_APP_TOKEN=xapp-...        # Slack Socket Mode token

# Optional:
BRAVE_SEARCH_API_KEY=BSA...     # Web search (brave.com/search/api)
```

### Required Config (`openclaw-secrets.json`)

The config template has placeholders you need to fill in. The critical ones:

**Discord** — you need your bot token, your Discord user ID, and your server (guild) ID:
```json
"channels": {
  "discord": {
    "enabled": true,
    "token": "${DISCORD_TOKEN}",
    "allowFrom": ["YOUR_DISCORD_USER_ID"],
    "guilds": {
      "YOUR_GUILD_ID": {
        "requireMention": false
      }
    }
  }
}
```

How to get the IDs:
1. **Bot token** — [Discord Developer Portal](https://discord.com/developers/applications) → Create Application → Bot → Reset Token. Enable **Message Content Intent** under Bot settings.
2. **Your user ID** — Enable Developer Mode (User Settings → Advanced → Developer Mode), then right-click your username → Copy User ID
3. **Guild ID** — Right-click your server name → Copy Server ID

**Invite the bot to your server:**
```
https://discord.com/api/oauth2/authorize?client_id=YOUR_APP_ID&permissions=412317273088&scope=bot
```

**Telegram** — set `enabled: true` and add your Telegram user ID to `allowFrom`. Get a bot token from [@BotFather](https://t.me/BotFather).

**Slack** — see the [Slack bot creation](#slack-bot-creation) section below.

### Auth Profiles (`openclaw-auth-profiles.json`)

This file maps provider names to actual API keys. Fill in the keys for providers you're using:

```json
{
  "version": 1,
  "profiles": {
    "anthropic:default": {
      "type": "api_key",
      "provider": "anthropic",
      "key": "sk-ant-..."
    },
    "openai:default": {
      "type": "api_key",
      "provider": "openai",
      "key": "sk-..."
    }
  }
}
```

### Run the Setup

```bash
# From the repo root:
shared/scripts/setup-openclaw.sh \
  --config openclaw-secrets.json \
  --env openclaw-secrets.env \
  --auth-profiles openclaw-auth-profiles.json

# Verify everything works:
shared/scripts/setup-openclaw.sh --check
```

This places your config at `~/.openclaw/openclaw.json`, your env at `~/.openclaw/.env`, installs the daemon, and starts the gateway.

### Bootstrap Workspace (Optional)

After OpenClaw is running, populate the workspace with starter files (SOUL.md, docs, tools, skills, cron jobs):

```bash
shared/scripts/bootstrap-openclaw-workspace.sh
```

## Customization

Edit `config.sh` to add/remove apps, tools, and settings:

```bash
code config.sh

# Preview what would change
./setup.sh --dry-run

# Run it
./setup.sh
```

### What's in `config.sh`

| Section | What you configure |
|---|---|
| `TAPS` | Homebrew taps |
| `FORMULAE` | CLI tools (brew install) |
| `CASKS` | GUI apps (brew install --cask) |
| `BUN_GLOBALS` | Pinned global npm/bun packages |
| `EXTENSIONS` | VS Code / Cursor extensions |
| `DIRS` | Directories to create |
| macOS defaults | Dock, Finder, dark mode, screenshots |
| `INSTALL_OPENCLAW` | Whether to install OpenClaw |
| `INSTALL_RUST` | Rust toolchain |
| `POST_SCRIPTS` | Scripts to run after setup |

### Usage

```bash
./setup.sh                          # Full setup
./setup.sh --dry-run                # Preview changes
./setup.sh --with-extensions        # Include VS Code / Cursor extensions
./setup.sh --extensions-only        # Only install editor extensions
./setup.sh --config my-config.sh    # Use a custom config file
```

### Claude Code Handoff

Run the automated setup, then drop into Claude Code to interactively finish CLI logins, SSH keys, and app sign-ins:

```bash
curl -fsSL mac.brennerspear.com | bash -s -- --handoff
```

## Slack Bot Creation

Create a Slack bot programmatically:

```bash
# 1. Get a config token from https://api.slack.com/apps
#    → Your App Configuration Tokens → Generate Token

# 2. Create the bot
scripts/create-slack-bot.sh <your-config-token>

# 3. Then manually:
#    - Generate an app-level token (xapp-...) for Socket Mode
#    - Install to your workspace
#    - Copy the bot token (xoxb-...)
```

The manifest at `shared/slack-app-manifest.json` includes all required scopes.

## Post-Setup (Manual)

Some things can't be automated:

- **Sign into apps** — 1Password, Slack, Discord, Tailscale, Spotify, etc.
- **CLI logins** — `gh auth login`, `vercel login`
- **SSH keys** — copy or generate `~/.ssh/` keys
- **Tailscale** — `tailscale up` (requires browser auth)
- **iCloud** — sign in via System Settings

## Scripts Reference

**In `scripts/`** (macOS-specific):

| Script | What it does |
|---|---|
| `setup-zshrc.sh` | Shell aliases, git shortcuts, AI agent commands |
| `create-slack-bot.sh` | Create Slack bot via Manifest API |
| `install-arc-extensions.sh` | Opens Chrome Web Store pages for extensions |
| `import-keyboard-shortcuts.sh` | Imports macOS keyboard shortcut plists |

**In `shared/scripts/`** (cross-platform):

| Script | What it does |
|---|---|
| `setup-openclaw.sh` | Non-interactive OpenClaw configuration |
| `bootstrap-openclaw-workspace.sh` | Workspace files, skills, cron jobs |
| `audit-openclaw.sh` | Compare existing install against this template |
| `smoke-test.sh` | Verify the model can respond |

## Auditing an Existing Install

Already have OpenClaw running? Compare your setup against this template:

```bash
cd ~/projects/openclaw-setup && shared/scripts/audit-openclaw.sh
```

Reports missing files, config conflicts, and extras you could upstream.

## For Teams

Fork this repo, edit `config.sh` for your team's stack, and give new hires the one-liner:

- Pin specific tool versions your codebase needs
- Add `POST_SCRIPTS` for team-specific config (VPN, internal tools)
- Create multiple config files: `config-eng.sh`, `config-design.sh`
- Pre-fill `openclaw-secrets.json` with non-sensitive defaults, have engineers add only their API keys

## License

MIT
