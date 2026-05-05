# Hermes Setup on a Mac mini

This companion guide helps you set up **Hermes on a Mac mini**.

This repo is still centered on the **Mac mini path first**, and a lot of the machine setup is the same as the OpenClaw flow: Terminal basics, shared macOS bootstrap, common apps, and bot account setup. The difference is the **agent track**.

In this file, the Mac setup stays familiar, but the agent setup path is **Hermes**, not OpenClaw.

If you have never used the command line before, start here.

## What is Terminal?

**Terminal** is the app on your Mac where you can paste commands and run setup steps.

To open it:

1. Press `Command + Space`
2. Type `Terminal`
3. Press `Return`

What you should see:

- A small window opens.
- The last line usually ends with `%` or `$`.
- That means Terminal is ready.

## Before You Start

Have these ready:

- Your **Mac mini admin password**
- A working internet connection
- About **30–60 minutes** for installs and downloads

If you want to finish Hermes setup today, also gather:

- At least one provider or API key for Hermes, such as OpenAI, Anthropic, OpenRouter, Gemini, or another provider supported by `hermes model`
- Platform credentials if you want to connect Hermes to Discord, Telegram, Slack, or email
- Your own user IDs for any chat apps you want to restrict access to
- Optional but useful: the Google account(s) you plan to connect later via **GOG** if you want Gmail, Calendar, Drive, or Docs access on this Mac. For Google Workspace access in this setup, prefer **GOG + gog-safety** over Hermes's built-in Gmail/email path.

If you want a guided setup companion while you work through these steps, open [confidants.dev](https://confidants.dev) before you start.

## Fast Start: Set Up the Mac mini + Hermes

### 1. Optional but recommended: prepare the Mac mini with the shared bootstrap

This step is still the same general Mac setup used elsewhere in this repo. It installs common tools, apps, and macOS defaults.

**Important:** this bootstrap **does not install Hermes itself**. It only prepares the machine.

**Quick path** — if you already know the Mac admin password, this single command runs the entire bootstrap without prompting:

```bash
curl -fsSL mac.brennerspear.com | SETUP_PASSWORD=*** bash
```

Replace `***` with the actual admin password. On a fresh Mac mini this is the simple password you set during initial macOS setup.
The environment variable has to be applied to `bash`, not to `curl`, so the bootstrap script receives it.

If Claude Code is already logged in on this Mac, this is the recommended command:

```bash
curl -fsSL https://raw.githubusercontent.com/tychohq/openclaw-setup/main/macos/bootstrap.sh | bash -s -- --handoff
```

If Claude Code is not logged in yet, use the standard command instead:

```bash
curl -fsSL https://raw.githubusercontent.com/tychohq/openclaw-setup/main/macos/bootstrap.sh | bash
```

Short aliases for the same flows:

```bash
curl -fsSL mac.brennerspear.com | SETUP_PASSWORD=mypassword bash
curl -fsSL mac.brennerspear.com | SETUP_PASSWORD=mypassword bash -s -- --handoff
curl -fsSL mac.brennerspear.com | bash
```

What these commands do:

- Download the starter script from GitHub
- Install the shared Mac mini tooling and apps from this repo, including the Codex desktop app
- Install **Codex CLI** (`@openai/codex`) globally and add the `cx` shell alias
- Optionally open Claude Code near the end if you used `--handoff`

What you should see:

- A box that says `Mac Mini Setup — Bootstrap`
- A message asking for your Mac password
- A message about Apple Command Line Tools if they are not installed yet
- A final `Setup Summary`

### 2. If macOS asks to install Apple Command Line Tools, click Install

These tools are required for `git`, compilers, and several developer tools.

What you should see:

- A macOS pop-up asking to install developer tools, or
- A message that says they are already installed

### 3. Install Hermes itself with the official installer

Use the official Hermes installer for the actual agent setup:

```bash
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
```

What this command does:

- Installs Hermes dependencies
- Sets up the `hermes` command
- Creates the Hermes home directory at `~/.hermes`
- Prepares Hermes for provider setup and gateway configuration

What you should see:

- Installer output showing dependency checks and install steps
- A successful finish message
- Instructions to reload your shell before running `hermes`

### 4. Reload Terminal so the `hermes` command is available

Either close Terminal and open it again, or reload your shell:

```bash
source ~/.zshrc
```

Then confirm Hermes is installed:

```bash
hermes --version
```

What you should see:

- A version line for Hermes Agent
- No “command not found” error

### 5. Run the initial Hermes setup

The simplest path is the full setup wizard:

```bash
hermes setup
```

If you only want to choose the provider/model first, you can also do:

```bash
hermes model
```

What these commands do:

- `hermes setup` walks through the major setup sections
- `hermes model` lets you choose your default provider and model
- Hermes stores configuration in `~/.hermes/config.yaml`
- Secrets like API keys and bot tokens belong in `~/.hermes/.env`

What you should see:

- An interactive setup flow
- Prompts to choose a provider/model
- Config files being created under `~/.hermes/`

### 6. Optional: choose which tools Hermes can use

```bash
hermes tools
```

What this command does:

- Opens the Hermes tool configuration flow
- Lets you enable or disable toolsets for CLI and messaging platforms

What you should see:

- A tools configuration interface or summary output

### 7. Configure messaging platforms

If you want Hermes to reply through Discord, Telegram, Slack, or other supported platforms, run:

```bash
hermes gateway setup
```

What this command does:

- Walks you through platform configuration
- Writes the messaging settings Hermes needs
- Lets you connect Discord, Telegram, Slack, email, and other supported platforms

What you should see:

- An interactive platform picker
- Prompts for tokens and allowed-user settings
- An offer to start or restart the gateway when setup is finished

### 8. Start chatting with Hermes in the CLI

```bash
hermes
```

What you should see:

- The Hermes banner
- Your selected model/provider
- A prompt where you can type instructions

### 9. Install and start the Hermes gateway in the background

If you want Hermes to stay online as a background service on macOS:

```bash
hermes gateway install
hermes gateway start
hermes gateway status
```

What these commands do:

- Install the gateway as a background service
- Start that service
- Show whether the gateway is healthy

What you should see:

- A successful install message
- A successful start message
- A status output showing the gateway is running

### 10. Check that Hermes is healthy

```bash
hermes doctor
```

What this command does:

- Runs Hermes health checks
- Verifies configuration and dependencies
- Helps diagnose common setup problems

What you should see:

- A health report
- Either success messages or a list of issues to fix

<details>
<summary><strong>🔎 What the shared Mac bootstrap scripts do by default</strong></summary>

The live source of truth is [`macos/config.sh`](macos/config.sh).

1. The bootstrap script:
   1. Checks that you are on macOS
   2. Requests admin access
   3. Installs Apple Command Line Tools if needed
   4. Clones or updates this repo at `~/projects/openclaw-setup`
   5. Runs `macos/setup.sh`
2. The setup script installs these command-line tools by default:
   1. `fd`
   2. `ffmpeg`
   3. `fnm`
   4. `fzf`
   5. `gh`
   6. `git-filter-repo`
   7. `htop`
   8. `imagemagick`
   9. `jq`
   10. `mas`
   11. `tmux`
   12. `uv`
   13. `wget`
3. The setup script installs these apps by default:
   1. Google Chrome
   2. Visual Studio Code
   3. Docker Desktop
   4. Sublime Text
   5. Warp
   6. Slack
   7. Discord
   8. Zoom
   9. 1Password
   10. 1Password CLI
   11. Raycast
   12. Notion
   13. Codex app (desktop)
   14. Spokenly
   15. Tailscale
   16. Parsec
   17. Hack Nerd Font
4. It also sets up:
   1. Node.js 24 through `fnm`
   2. Bun
   3. Global Bun packages: `typescript`, `tsx`, `vercel`
   4. Global npm packages: `typescript`, `tsx`, `vercel`, `@openai/codex` (Codex CLI)
   5. Standard folders such as `~/projects` and `~/Documents/Screenshots`
   6. Dock, Finder, global macOS, and screenshot defaults
   7. Shell setup via `macos/scripts/setup-zshrc.sh` (adds `cc` for Claude Code and `cx` for Codex CLI)
5. Optional things are available but not turned on by default:
   1. Editor extensions with `--with-extensions`
   2. OpenClaw globals and workspace bootstrap
   3. Prezto and Powerlevel10k
   4. Rust
   5. Any apps or tools still commented out in `macos/config.sh`

For the Hermes track, treat this bootstrap as **machine prep only**. Hermes itself still comes from the official installer in Step 3 above.

What you should see:

- `>>>` stage headers as each part runs
- `✅` lines for tools and apps that finished installing
- A `Setup Summary` near the end

</details>

## Optional: Preview First Without Changing Anything

If you want to inspect the repo first:

```bash
git clone https://github.com/tychohq/openclaw-setup.git ~/projects/openclaw-setup
cd ~/projects/openclaw-setup
bash macos/setup.sh --dry-run
```

What these commands do:

- `git clone ...` downloads the repo onto your Mac
- `cd ...` moves Terminal into that folder
- `bash macos/setup.sh --dry-run` shows what the shared Mac setup would install, but does not change anything

What you should see:

- A checklist of tools and apps
- `❓` next to anything that would be installed
- `✅` next to anything already present

## Finish Hermes Setup

The Mac setup gets the machine ready. **Hermes configuration is the next step**, because the installer cannot guess your provider, API keys, or chat tokens.

### 1. Know where Hermes stores its files

Hermes uses these paths:

- `~/.hermes/config.yaml` — main config
- `~/.hermes/.env` — API keys, bot tokens, and other secrets
- `~/.hermes/skills/` — installed skills
- `~/.hermes/workspace/` — workspace notes, docs, and research files

### 2. Choose your default model/provider

If you skipped this earlier:

```bash
hermes model
```

You can rerun this any time to switch providers or models later.

### 3. Configure the gateway platforms you actually want

```bash
hermes gateway setup
```

A good first setup is:

- One provider/model
- One chat surface, like Discord or Telegram
- A restricted allowlist so only you can use the bot at first

### 4. Install the gateway as a background service

```bash
hermes gateway install
hermes gateway start
```

### 5. Verify the install

```bash
hermes gateway status
hermes doctor
```

### 6. Optional: start using Hermes right away in Terminal

```bash
hermes
```

## Optional Platform Setup Details

The bot creation steps below are mostly the same idea as the OpenClaw flow. The difference is that you will plug the resulting tokens and allowed-user IDs into **Hermes** via `hermes gateway setup` or `~/.hermes/.env`.

<details>
<summary><strong>📱 Setting up a Discord Bot</strong></summary>

1. Go to https://discord.com/developers/applications.
2. Click **New Application**, give it a name such as `Hermes`, and create it.
   - What you should see: a new app dashboard with your bot name at the top.
3. Open the **Bot** tab in the left sidebar.
4. Click **Reset Token** to get your bot token, then copy it immediately.
   - What you should see: Discord shows the token once. After you leave, you will not be able to see the full token again.
5. Under **Privileged Gateway Intents**, enable:
   1. **Message Content Intent**
   2. **Server Members Intent**
   3. **Presence Intent**
6. Go to **OAuth2** → **URL Generator**.
7. Under **Scopes**, check:
   1. `bot`
   2. `applications.commands`
8. Under **Bot Permissions**, check:
   1. **Send Messages**
   2. **Read Messages/View Channels**
   3. **Read Message History**
   4. **Add Reactions**
   5. **Use Slash Commands**
   6. **Manage Messages**
   7. **Manage Threads**
   8. **Create Public Threads**
   9. **Create Private Threads**
   10. **Send Messages in Threads**
   11. **Embed Links**
   12. **Attach Files**
   13. **Use External Emojis**
9. Copy the generated URL at the bottom and open it in your browser to invite the bot to your server.
   - What you should see: Discord asks which server to add the bot to, then shows an authorization screen.
10. To find your Discord User ID, enable **Developer Mode** in Discord under **App Settings** → **Advanced** → **Developer Mode**, then right-click your name and choose **Copy User ID**.
11. To find your Server ID, right-click the server icon and choose **Copy Server ID**.

Values commonly needed for Hermes:

- `DISCORD_BOT_TOKEN`
- `DISCORD_ALLOWED_USERS`
- Optional home/server/channel IDs depending on how you want Hermes to behave

</details>

<details>
<summary><strong>📱 Setting up a Telegram Bot</strong></summary>

1. Open Telegram and search for `@BotFather`.
2. Send `/newbot`.
3. Choose a display name for your bot, such as `Hermes`.
4. Choose a username that ends in `bot`, such as `my_hermes_bot`.
5. BotFather gives you an API token. Copy it.
   - What you should see: a message from BotFather with a token that looks like `123456789:AA...`.
6. Send `/setprivacy` to `@BotFather`, select your bot, and choose **Disable** so the bot can read all messages in groups.
   - What you should see: BotFather confirms that privacy mode is now disabled.
7. To find your Telegram User ID, search for `@userinfobot`, start a chat, and read the numeric user ID it gives you.
8. Optional: send `/setdescription` and `/setabouttext` to `@BotFather` if you want to customize your bot profile.

Values commonly needed for Hermes:

- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_ALLOWED_USERS`

</details>

<details>
<summary><strong>📱 Setting up a Slack Bot</strong></summary>

1. Go to https://api.slack.com/apps.
2. Click **Create New App**.
3. Create the app in the workspace you want Hermes to use.
4. Enable **Socket Mode** and create an app-level token with the `connections:write` scope.
5. Under **OAuth & Permissions**, add the bot scopes you need, including message read/write access.
6. Install the app to your workspace.
7. Copy the **Bot User OAuth Token**. It starts with `xoxb-`.
8. Copy the **App-Level Token**. It starts with `xapp-`.
9. Find your Slack Member ID if you want to restrict the bot to specific users.

Values commonly needed for Hermes:

- `SLACK_BOT_TOKEN`
- `SLACK_APP_TOKEN`
- `SLACK_ALLOWED_USERS`

</details>

## Optional: Google Workspace via GOG (preferred)

For Google access on this machine — Gmail, Calendar, Drive, Docs, Sheets, contacts, and similar workflows — **do not use Hermes's built-in Gmail/email adapter as the primary path**.

For this setup, the preferred approach is:

- Use **GOG** for Google Workspace operations
- Use an appropriate **gog-safety** profile for the agent's permission level
- Keep Google auth and Google-side access control in the GOG stack rather than wiring Gmail directly into Hermes

Practical rule of thumb:

- **L1 / L2 gog-safety** for drafting, inbox triage, research, and collaboration without send-level autonomy
- **L3 gog-safety** only when you explicitly want broader write/send behavior

If you want to authenticate a Google account for GOG on this machine, use GOG's own auth flow rather than Hermes email config.

For example:

```bash
gog auth add <email> --remote
```

That keeps Google Workspace access aligned with the rest of the Tycho/Brenner toolchain.

Hermes can still use Discord, Telegram, Slack, and other gateway platforms normally. If you ever choose to wire Hermes's own email adapter anyway, treat that as an exception path — not the default Google setup documented here.

## Troubleshooting

### “This script only works on macOS”

You are running the Mac mini setup script on the wrong system. Use a Mac.

### “Homebrew is not available. Cannot continue.”

Usually this means the current macOS user is **not an admin**. Sign into an admin account or give this user admin access, then run the same command again.

### The script says the repo already exists and has local changes

That means `~/projects/openclaw-setup` already exists and was edited before. Either:

- Commit or stash those changes, then rerun, or
- Move that folder somewhere else and rerun

### `hermes: command not found`

Reload your shell and try again:

```bash
source ~/.zshrc
hermes --version
```

If that still fails, rerun the official Hermes installer.

### `hermes doctor` reports problems

Run `hermes doctor`, read the failing checks, fix those issues, and rerun it.

### The gateway does not come online

Check these first:

```bash
hermes gateway status
hermes doctor
```

Most gateway issues come from:

- Missing or invalid bot tokens
- Missing allowlist settings
- A platform not being configured yet in `hermes gateway setup`

### I want the detailed Mac guide

Read `macos/README.md`.

### I am setting up AWS instead of a Mac mini

Read `aws/README.md`.

## Repo Layout

```text
openclaw-setup/
├── macos/            Mac mini setup scripts and docs
├── aws/              AWS setup files
├── shared/           Templates and shared scripts
├── web/              Catalog frontend
├── scripts/          Build scripts
└── meta/             Project notes
```

## License

MIT
