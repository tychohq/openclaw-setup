# openclaw-setup

This repo helps you set up **OpenClaw on a Mac mini**. It also contains AWS files, but this README is written for the **Mac mini path first**.

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

If you want to finish OpenClaw setup today, also gather:

If you want a guided setup companion while you work through these steps, open [confidants.dev](https://confidants.dev) before you start.

- At least one AI provider key, like Anthropic, OpenAI, OpenRouter, or Gemini
- At least one chat channel token, like Discord, Telegram, or Slack

## Fast Start: Set Up the Mac mini

### 1. Paste this into Terminal

Replace `mypassword` with your Mac's admin password. On a fresh Mac mini this is the simple password you set during initial macOS setup.

```bash
SETUP_PASSWORD=mypassword curl -fsSL mac.brennerspear.com | bash
```

This downloads and runs the bootstrap script, which:

1. Installs **Apple Command Line Tools** (compilers, `git`)
2. Installs **Homebrew** (the Mac package manager)
3. Installs **CLI tools**: `git`, `gh`, `tmux`, `uv`, `jq`, `fzf`, `ffmpeg`, and more
4. Installs **apps**: Chrome, Arc, Cursor, VS Code, Warp, Slack, Discord, 1Password, Raycast, Claude, and more
5. Installs **Bun** and **Node.js 24**
6. Applies **Mac settings**: Dock, Finder, dark mode, screenshots, sleep prevention
7. Sets up **shell aliases** in `~/.zshrc` (including `cc` for Claude Code)
8. Clones this repo to `~/projects/openclaw-setup`

macOS will show pop-ups asking to install developer tools or approve permissions. Click **Install** or **Allow** on any pop-ups that appear.

What you should see:

- A box that says `Mac Mini Setup — Bootstrap`
- Lines starting with `>>>` for each stage
- Lots of `✅` lines for things that were installed
- A final `Setup Summary`

If the script stops, read the last `❌` message, fix that issue, and run the same command again. The setup is safe to rerun.


<details>
<summary><strong>What the bootstrap and setup scripts do by default</strong></summary>

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
   1. Arc
   2. Google Chrome
   3. Cursor
   4. Visual Studio Code
   5. Docker Desktop
   6. Sublime Text
   7. Warp
   8. Slack
   9. Discord
   10. Zoom
   11. 1Password
   12. 1Password CLI
   13. Raycast
   14. Notion
   15. ChatGPT
   16. Claude
   17. Spokenly
   18. Spotify
   19. VLC
   20. Tailscale
   21. Hack Nerd Font
4. It also sets up:
   1. Node.js 24 through `fnm`
   2. Bun
   3. Global Bun packages: `typescript`, `tsx`, `vercel`
   4. Standard folders such as `~/projects` and `~/Documents/Screenshots`
   5. Dock, Finder, global macOS, and screenshot defaults
   6. Shell setup via `macos/scripts/setup-zshrc.sh`
5. Optional things are available but not turned on by default:
   1. Editor extensions with `--with-extensions`
   2. OpenClaw globals and workspace bootstrap
   3. Prezto and Powerlevel10k
   4. Rust
   5. Any apps or tools still commented out in `macos/config.sh`

</details>


### 2. Log in to Claude Code

Once the setup script finishes, **close that Terminal window** and **open a new one** (so the new shell aliases are loaded).

Then log in to Claude Code:

```bash
claude auth login
```

This opens a browser sign-in flow for your Anthropic account. Follow the prompts to authenticate.

What you should see:

- Claude Code opens a sign-in page in your browser
- A success message after you finish logging in

### 3. Start Claude Code

Now start Claude Code with full permissions:

```bash
cd ~/projects/openclaw-setup
cc
```

`cc` is a shell alias set up by the bootstrap script. It runs `claude --dangerously-skip-permissions`, which lets Claude Code read, write, and run commands without asking for approval on each one.

What you should see:

- Claude Code starts in the `openclaw-setup` directory
- A prompt where you can type instructions

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
- `bash macos/setup.sh --dry-run` shows what would be installed, but does not change anything

What you should see:

- A checklist of tools and apps
- `❓` next to anything that would be installed
- `✅` next to anything already present

## Finish OpenClaw Setup

The bootstrap command clones or updates this repo at `~/projects/openclaw-setup` automatically. The commands below assume you are running them from that folder.

The Mac setup script prepares the machine. **OpenClaw configuration is the next step**, because the script cannot guess your secret keys.

### 1. Create your three local config files

From the repo root (by default `~/projects/openclaw-setup` when you used the bootstrap command):

```bash
cp shared/config/openclaw-config.template.json openclaw-secrets.json
cp shared/config/openclaw-env.template openclaw-secrets.env
cp shared/config/openclaw-auth-profiles.template.json openclaw-auth-profiles.json
```

What these commands do:

- They copy template files into new local files you can edit safely
- These new files are ignored by git and should not be committed

What you should see:

- No big output is normal
- The new files appear in the repo folder

### 2. Fill in your keys and IDs

You need:

- At least one AI provider key
- At least one chat channel token
- Any required user IDs or server IDs for that chat app


<details>
<summary><strong>📱 Setting up a Discord Bot</strong></summary>

1. Go to https://discord.com/developers/applications.
2. Click **New Application**, give it a name such as `OpenClaw`, and create it.
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

Values needed for OpenClaw config:

- `DISCORD_TOKEN` in the `.env` file
- Your user ID in the authorized senders list
- Your server or guild ID in the Discord channel config

</details>

<details>
<summary><strong>📱 Setting up a Telegram Bot</strong></summary>

1. Open Telegram and search for `@BotFather`.
2. Send `/newbot`.
3. Choose a display name for your bot, such as `OpenClaw`.
4. Choose a username that ends in `bot`, such as `my_openclaw_bot`.
5. BotFather gives you an API token. Copy it.
   - What you should see: a message from BotFather with a token that looks like `123456789:AA...`.
6. Send `/setprivacy` to `@BotFather`, select your bot, and choose **Disable** so the bot can read all messages in groups.
   - What you should see: BotFather confirms that privacy mode is now disabled.
7. To find your Telegram User ID, search for `@userinfobot`, start a chat, and read the numeric user ID it gives you.
8. Optional: send `/setdescription` and `/setabouttext` to `@BotFather` if you want to customize your bot profile.

Values needed for OpenClaw config:

- `TELEGRAM_BOT_TOKEN` in the `.env` file
- Your numeric user ID for authorized senders

</details>

<details>
<summary><strong>📱 Setting up a Slack Bot</strong></summary>

1. Go to https://api.slack.com/apps.
2. Click **Create New App** → **From a manifest**.
3. Select your workspace.
4. If the repo has a manifest file at `shared/slack-app-manifest.json`, paste its contents into the manifest editor. Otherwise create the app manually with:
   1. A bot name
   2. **Socket Mode** enabled
   3. Bot token scopes: `chat:write`, `channels:history`, `channels:read`, `groups:history`, `groups:read`, `im:history`, `im:read`, `mpim:history`, `mpim:read`, `reactions:read`, `reactions:write`, `files:read`, `files:write`, `users:read`
   4. Event subscriptions: `message.channels`, `message.groups`, `message.im`, `message.mpim`, `app_mention`
   - What you should see: Slack accepts the manifest and creates an app configuration screen.
5. Install the app to your workspace.
6. Get the bot token from **OAuth & Permissions** by copying the **Bot User OAuth Token**. It starts with `xoxb-`.
7. Get the app token from **Basic Information** → **App-Level Tokens** by generating a token with the `connections:write` scope. It starts with `xapp-`.
   - What you should see: both tokens are shown in Slack after creation, with the prefixes above.

Values needed for OpenClaw config:

- `SLACK_BOT_TOKEN` in the `.env` file
- `SLACK_APP_TOKEN` in the `.env` file

</details>

### 3. Run the OpenClaw setup script

```bash
bash shared/scripts/setup-openclaw.sh \
  --config openclaw-secrets.json \
  --env openclaw-secrets.env \
  --auth-profiles openclaw-auth-profiles.json
```

What this command does:

- Copies your config into `~/.openclaw/`
- Installs or restarts the OpenClaw background service
- Prepares the OpenClaw workspace folder

What you should see:

- `>>> Setting up OpenClaw...`
- Several `✅` lines
- A final message showing `Config: ~/.openclaw/openclaw.json`

### 4. Check that OpenClaw is healthy

```bash
bash shared/scripts/setup-openclaw.sh --check
```

What you should see:

- `✅ openclaw CLI found`
- `✅ Config file exists`
- `✅ OpenClaw installation looks good!`

### 5. Optional: Bootstrap the workspace files

```bash
bash shared/scripts/bootstrap-openclaw-workspace.sh
```

What this command does:

- Copies starter files like `AGENTS.md`, `SOUL.md`, `USER.md`, and docs into `~/.openclaw/workspace`
- Installs shared skills if `clawhub` is installed

What you should see:

- `>>> Setting up OpenClaw workspace...`
- `✅` lines for copied files and created folders

## Troubleshooting

### “This script only works on macOS”

You are running the Mac mini setup script on the wrong system. Use a Mac.

### “Homebrew is not available. Cannot continue.”

Usually this means the current macOS user is **not an admin**. Sign into an admin account or give this user admin access, then run the same command again.

### The script says the repo already exists and has local changes

That means `~/projects/openclaw-setup` already exists and was edited before. Either:

- Commit or stash those changes, then rerun, or
- Move that folder somewhere else and rerun

### OpenClaw setup was skipped

That usually means your local secrets files were still templates or missing. Fill in the three `openclaw-secrets*` files, then rerun:

```bash
bash shared/scripts/setup-openclaw.sh \
  --config openclaw-secrets.json \
  --env openclaw-secrets.env \
  --auth-profiles openclaw-auth-profiles.json
```

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
