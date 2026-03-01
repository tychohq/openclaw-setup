# Mac Mini Setup

One command to go from a fresh Mac mini to a fully configured dev machine.

```bash
curl -fsSL mac.brennerspear.com | bash
```

Or with **Claude Code handoff** — runs the automated setup, then drops you into Claude Code to interactively finish the rest (CLI logins, SSH keys, API keys, app sign-ins):

```bash
curl -fsSL mac.brennerspear.com | bash -s -- --handoff
```

## What it does

1. Installs Xcode Command Line Tools
2. Installs Homebrew
3. Installs CLI tools (fd, fzf, gh, tmux, uv, etc.)
4. Installs apps via Homebrew Cask (Slack, Discord, Arc, Cursor, 1Password, etc.)
5. Installs Bun + global packages (TypeScript, Vercel CLI, etc.)
6. Sets up Node.js via fnm
7. Optionally installs Rust, Prezto/Powerlevel10k, OpenClaw
8. Applies macOS defaults (dock, Finder, dark mode, etc.)
9. Creates directory structure
10. Installs VS Code / Cursor extensions (opt-in)

Everything is **idempotent** — safe to run multiple times. It skips what's already installed and reports what changed.

## Customization

Edit `config.sh` to add/remove apps, tools, and settings:

```bash
git clone https://github.com/BrennerSpear/mac-mini-setup.git ~/projects/mac-mini-setup
cd ~/projects/mac-mini-setup

# Edit the config
code config.sh   # or: subl config.sh

# Preview what would change
./setup.sh --dry-run

# Run it
./setup.sh
```

## Usage

```bash
# Full setup (default — no editor extensions)
./setup.sh

# Preview changes without applying
./setup.sh --dry-run

# Include VS Code / Cursor extensions
./setup.sh --with-extensions

# Install only editor extensions
./setup.sh --extensions-only

# Use a custom config
./setup.sh --config my-team-config.sh
```

## What's in `config.sh`

| Section | What you configure |
|---|---|
| `TAPS` | Homebrew taps |
| `FORMULAE` | CLI tools (brew install) |
| `CASKS` | GUI apps (brew install --cask) |
| `BUN_GLOBALS` | Pinned global npm/bun packages |
| `EXTENSIONS` | VS Code / Cursor extensions |
| `DIRS` | Directories to create |
| macOS defaults | Dock, Finder, dark mode, screenshots |
| `INSTALL_OPENCLAW` | OpenClaw + agent tools |
| `INSTALL_RUST` | Rust toolchain |
| `POST_SCRIPTS` | Scripts to run after setup |

## OpenClaw Setup

OpenClaw can be configured **non-interactively** using a JSON config file + env file:

### Quick start

```bash
# 1. Copy templates
cp config/openclaw-config.template.json openclaw-secrets.json
cp config/openclaw-env.template openclaw-secrets.env
cp config/openclaw-auth-profiles.template.json openclaw-auth-profiles.json

# 2. Fill in your API keys and channel tokens
code openclaw-secrets.json openclaw-secrets.env openclaw-auth-profiles.json

# 3. Run setup (or set INSTALL_OPENCLAW=true in config.sh and run setup.sh)
scripts/setup-openclaw.sh --config openclaw-secrets.json --env openclaw-secrets.env --auth-profiles openclaw-auth-profiles.json

# 4. Verify
scripts/setup-openclaw.sh --check
```

The secrets files are `.gitignored` — safe to keep in the repo root locally.

### Config template structure

**`config/openclaw-config.template.json`** — Full OpenClaw config:
- AI provider settings (models, auth profiles, fallback chains)
- Channel configs (Discord, Telegram, Slack — each with access control)
- Gateway settings (port, auth, trusted proxies)
- Memory, skills, plugins
- Agent defaults (model, workspace, heartbeat)

**`config/openclaw-env.template`** — API keys and tokens:
- AI provider keys (Anthropic, OpenAI, OpenRouter, Gemini)
- Channel tokens (Discord bot token, Telegram bot token, Slack tokens)
- Service keys (Brave Search, etc.)

**`config/openclaw-auth-profiles.template.json`** — Provider auth profiles:
- Actual API keys/tokens per provider profile (Anthropic, OpenAI, OpenRouter, etc.)
- Placed at `~/.openclaw/agents/main/agent/auth-profiles.json`
- Supports multiple profiles per provider (e.g., API key + Max Plan token)

### Discord bot setup

To connect OpenClaw to Discord, you need 3 IDs:

1. **Bot token** — from [Discord Developer Portal](https://discord.com/developers/applications)
   - Create application → Bot → Reset Token → copy it
   - Under Bot settings, enable **Message Content Intent**
2. **Your Discord user ID** — right-click your username → Copy User ID
   - (Enable Developer Mode first: User Settings → Advanced → Developer Mode)
3. **Guild (server) ID** — right-click the server name → Copy Server ID
4. **Channel IDs** — right-click each channel → Copy Channel ID

Then in your `openclaw-secrets.json`, fill in these 3 values:
```json
"channels": {
  "discord": {
    "enabled": true,
    "token": "paste-your-bot-token-here",
    "groupPolicy": "allowlist",
    "dmPolicy": "pairing",
    "requireMention": false,
    "allowFrom": ["paste-your-discord-user-id"],
    "guilds": {
      "paste-your-guild-id": {
        "requireMention": false
      }
    }
  }
}
```

That's it — listing a guild ID allows **all channels** in that server. You only need to add a `channels` object if you want per-channel system prompts:

```json
"guilds": {
  "987654321...": {
    "requireMention": false,
    "channels": {
      "111222333...": {
        "allow": true,
        "systemPrompt": "This channel is for research tasks..."
      }
    }
  }
}
```

**Invite the bot to your server:**
```
https://discord.com/api/oauth2/authorize?client_id=YOUR_APP_ID&permissions=412317273088&scope=bot
```

### Slack bot creation

Create a Slack bot programmatically without the UI:

```bash
# 1. Get a config token from https://api.slack.com/apps
#    → Your App Configuration Tokens → Generate Token

# 2. Create the bot (uses the manifest in config/slack-app-manifest.json)
scripts/create-slack-bot.sh <your-config-token>

# 3. The script creates the app with all scopes and Socket Mode.
#    You'll need to manually:
#    - Generate an app-level token (xapp-...) for Socket Mode
#    - Install to your workspace
#    - Copy the bot token (xoxb-...)
```

The manifest at `config/slack-app-manifest.json` includes all scopes OpenClaw needs:
- Message read/write across channels, DMs, groups
- Reactions, pins, files, emoji
- Socket Mode enabled by default

## Post-setup (manual)

Some things can't be automated — the setup script reminds you:

- **Sign into apps**: 1Password, Slack, Discord, Tailscale, Spotify, etc.
- **Raycast**: Sign in to sync settings (has its own cloud sync)
- **CLI logins**: `gh auth login`, `vercel login`
- **SSH keys**: Copy or generate `~/.ssh/` keys
- **Tailscale**: `tailscale up` (requires browser auth)
- **iCloud**: Sign in via System Settings

## Optional scripts

In the `scripts/` directory:

| Script | What it does |
|---|---|
| `setup-zshrc.sh` | Shell aliases, git shortcuts, AI agent commands (`cc`, `claumux`, etc.) |
| `setup-openclaw.sh` | Non-interactive OpenClaw configuration |
| `bootstrap-openclaw-workspace.sh` | Workspace files, clawhub skills, custom skills, cron jobs |
| `audit-openclaw.sh` | Compare existing OpenClaw against this template |
| `create-slack-bot.sh` | Create Slack bot via Manifest API |
| `install-arc-extensions.sh` | Opens Chrome Web Store pages for extensions |
| `import-keyboard-shortcuts.sh` | Imports macOS keyboard shortcut plists |

Enable post-scripts in `config.sh`:
```bash
POST_SCRIPTS=(
  "scripts/import-keyboard-shortcuts.sh"
  "scripts/install-arc-extensions.sh"
)
```

## Auditing an existing install

Already have OpenClaw running? Compare your setup against this template:

```bash
# Clone the repo (if you haven't)
git clone https://github.com/BrennerSpear/mac-mini-setup.git ~/projects/mac-mini-setup

# Run the audit
cd ~/projects/mac-mini-setup && ./scripts/audit-openclaw.sh
```

This compares your workspace files, config, skills, and git config against the template and reports:
- **Missing** — things the template has that you don't
- **Conflicts** — settings that differ between your install and the template
- **Extras** — things you have that could be worth upstreaming

Or ask your OpenClaw to do it:
> "Clone https://github.com/BrennerSpear/mac-mini-setup.git to ~/projects/mac-mini-setup and run scripts/audit-openclaw.sh, then read scripts/audit-prompt.md and give me a full analysis"

## For teams

Fork this repo, edit `config.sh` for your team's stack, and give new hires the one-liner. Consider:

- Adding your team's Slack workspace setup instructions
- Pinning specific tool versions your codebase needs
- Adding `POST_SCRIPTS` for team-specific config (VPN, internal tools, etc.)
- Creating multiple config files: `config-eng.sh`, `config-design.sh`, etc.
- Pre-filling an `openclaw-secrets.json` with non-sensitive defaults (model configs, scopes) and having engineers add only their API keys

## License

MIT
