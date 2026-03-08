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

- At least one AI provider key, like Anthropic, OpenAI, OpenRouter, or Gemini
- At least one chat channel token, like Discord, Telegram, or Slack

## Fast Start: Set Up the Mac mini

### 1. Paste this into Terminal

If Claude Code is already logged in on this Mac, this is the recommended command:

```bash
curl -fsSL https://raw.githubusercontent.com/tychohq/openclaw-setup/main/macos/bootstrap.sh | bash -s -- --handoff
```

What this command does:

- `curl` downloads the starter script from GitHub
- `| bash -s -- --handoff` runs that script and passes `--handoff` into `macos/setup.sh`
- At the end of setup, Claude Code opens so it can help if anything breaks

What you should see:

- A box that says `Mac Mini Setup — Bootstrap`
- A message asking for your Mac password
- A message about Apple Command Line Tools if they are not installed yet
- Claude Code opening near the end of setup if the install completes cleanly

If Claude Code is not logged in yet, use the standard command instead:

```bash
curl -fsSL https://raw.githubusercontent.com/tychohq/openclaw-setup/main/macos/bootstrap.sh | bash
```

Short aliases for the same flows:

```bash
curl -fsSL mac.brennerspear.com | bash -s -- --handoff
curl -fsSL mac.brennerspear.com | bash
```

### 2. If macOS asks to install Apple Command Line Tools, click Install

These tools are required for `git`, compilers, and several developer tools.

What you should see:

- A macOS pop-up asking to install developer tools, or
- A message that says they are already installed

### 3. Wait while the setup script runs

The script then:

1. Installs Homebrew
2. Installs command-line tools like `git`, `gh`, `tmux`, `uv`, and `jq`
3. Installs apps like Slack, Discord, Cursor, Arc, and 1Password
4. Installs Bun and Node.js
5. Applies Mac settings like Dock and Finder defaults
6. Creates the standard folders used by this setup

What you should see:

- Lines starting with `>>>` for each stage
- Lots of `✅` lines for things that were installed
- A final `Setup Summary`

If the script stops, read the last `❌` message, fix that issue, and run the same command again. The setup is designed to be safe to rerun.

### 4. If you have a Claude subscription, sign in to Claude Code

The Mac setup installs Claude Code for you. If you sign in now, Claude Code can help with the rest of the setup.

```bash
claude auth login
claude auth status --text
```

What these commands do:

- `claude auth login` starts the Claude Code sign-in flow for your Anthropic account
- `claude auth status --text` confirms whether Claude Code is signed in

What you should see:

- Claude Code opens a sign-in flow
- A successful status message after you finish logging in

If you want Claude Code to take over right away after that:

```bash
cd ~/projects/openclaw-setup
bash macos/setup.sh --handoff
```

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
