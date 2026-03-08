# Mac mini Setup

This guide is for setting up a **fresh Apple Silicon Mac mini** for OpenClaw.

It is written for someone who may be brand new to Terminal.

## What You Are About to Do

You will:

1. Open Terminal
2. Run one starter command
3. Let the script install the missing tools your Mac needs
4. Fill in your OpenClaw keys and tokens
5. Run the OpenClaw config script

## Step 1: Open Terminal

Terminal is the built-in app where you paste commands.

To open it:

1. Press `Command + Space`
2. Type `Terminal`
3. Press `Return`

What you should see:

- A window opens
- The last line usually ends with `%` or `$`

## Step 2: Run the bootstrap command

If Claude Code is already logged in on this Mac, paste this into Terminal and press `Return`:

```bash
curl -fsSL https://raw.githubusercontent.com/tychohq/openclaw-setup/main/macos/bootstrap.sh | bash -s -- --handoff
```

Plain-English explanation:

- `curl` downloads the starter script
- `| bash -s -- --handoff` runs it and passes `--handoff` into `macos/setup.sh`
- At the end of setup, Claude Code opens so it can help if anything breaks

What you should see:

- `Mac Mini Setup — Bootstrap`
- A request for your Mac password
- Claude Code opening near the end of setup if the install completes cleanly

If Claude Code is not logged in yet, use the standard bootstrap command instead:

```bash
curl -fsSL https://raw.githubusercontent.com/tychohq/openclaw-setup/main/macos/bootstrap.sh | bash
```

Short aliases for the same script:

```bash
curl -fsSL mac.brennerspear.com | bash -s -- --handoff
curl -fsSL mac.brennerspear.com | bash
```

## Step 3: Let Apple install Command Line Tools if needed

On a brand-new Mac, macOS may open a pop-up window asking to install **Apple Command Line Tools**.

This is normal.

What you should do:

1. Click **Install**
2. Wait for it to finish
3. Return to Terminal

What you should see:

- Either a pop-up asking you to install the tools, or
- `✅ Apple Command Line Tools already installed`

## Step 4: Wait for the machine setup to finish

After that, the script runs `macos/setup.sh` for you.

It installs:

- Homebrew
- Common command-line tools
- Apps like Arc, Chrome, Cursor, Slack, Discord, Spokenly, Raycast, and 1Password
- Bun
- Node.js
- Standard folders and Mac defaults

What you should see:

- Stage headings starting with `>>>`
- `✅` lines for successful steps
- A `Setup Summary` at the end

If something fails:

- Read the last `❌` line carefully
- Fix that problem
- Run the same bootstrap command again

The script is safe to rerun.


<details>
<summary><strong>🔎 What the bootstrap and setup scripts do by default</strong></summary>

The live source of truth is [`macos/config.sh`](config.sh).

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

What you should see:

- `>>>` stage headers as each part runs
- `✅` lines for tools and apps that finished installing
- A `Setup Summary` near the end

</details>


## Step 5: If you have a Claude subscription, sign in to Claude Code

The Mac setup installs Claude Code for you. If you sign in now, Claude Code can help with the rest of the setup.

```bash
claude auth login
claude auth status --text
```

Plain-English explanation:

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

## Step 6: Optional preview mode

If you want to review the plan before changing anything:

```bash
git clone https://github.com/tychohq/openclaw-setup.git ~/projects/openclaw-setup
cd ~/projects/openclaw-setup
bash macos/setup.sh --dry-run
```

What you should see:

- `❓` items that would be installed
- `✅` items that are already there

## Step 7: Create your OpenClaw config files

The bootstrap command clones or updates this repo at `~/projects/openclaw-setup` automatically. The commands below assume you are running them from that folder.

From the repo root (by default `~/projects/openclaw-setup` when you used the bootstrap command), run:

```bash
cp shared/config/openclaw-config.template.json openclaw-secrets.json
cp shared/config/openclaw-env.template openclaw-secrets.env
cp shared/config/openclaw-auth-profiles.template.json openclaw-auth-profiles.json
```

Plain-English explanation:

- These commands make local copies of the template files
- You will edit the local copies with your real keys and IDs

What you should see:

- Usually no output at all
- Three new files in the repo root

## Step 8: Fill in the files

You need at least:

- One AI provider key
- One chat channel token

### `openclaw-secrets.env`

Use this for secret keys and tokens.

Examples:

```dotenv
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
OPENROUTER_API_KEY=sk-or-...
GEMINI_API_KEY=AI...

DISCORD_TOKEN=...
TELEGRAM_BOT_TOKEN=...
SLACK_BOT_TOKEN=...
SLACK_APP_TOKEN=...
```

### `openclaw-secrets.json`

Use this for channel setup and general OpenClaw settings.

For Discord, the most important fields are:

- Your bot token
- Your Discord user ID
- Your server ID

### `openclaw-auth-profiles.json`

Use this for provider auth profiles such as Anthropic, OpenAI, and OpenRouter.


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

## Step 9: Run OpenClaw setup

```bash
bash shared/scripts/setup-openclaw.sh \
  --config openclaw-secrets.json \
  --env openclaw-secrets.env \
  --auth-profiles openclaw-auth-profiles.json
```

Plain-English explanation:

- Copies your settings into `~/.openclaw/`
- Installs the OpenClaw background service if needed
- Starts or restarts the service

What you should see:

- `>>> Setting up OpenClaw...`
- `✅ Directory: ~/.openclaw`
- `✅ Config installed` or `✅ Config merged`
- `✅ Gateway installed and started` or `✅ Gateway restarted`

## Step 10: Check your install

```bash
bash shared/scripts/setup-openclaw.sh --check
```

What you should see:

- `✅ openclaw CLI found`
- `✅ Config file exists`
- `✅ OpenClaw installation looks good!`

## Step 11: Optional workspace bootstrap

If you also want starter workspace files:

```bash
bash shared/scripts/bootstrap-openclaw-workspace.sh
```

What you should see:

- `>>> Setting up OpenClaw workspace...`
- `✅` lines for folders and copied files

## Helpful Commands

### Preview the Mac setup without changing anything

```bash
bash macos/setup.sh --dry-run
```

### Recommended: run the full Mac setup with Claude Code handoff

If Claude Code is already logged in on this Mac:

```bash
cd ~/projects/openclaw-setup
bash macos/setup.sh --handoff
```

If Claude Code is not logged in yet:

```bash
cd ~/projects/openclaw-setup
bash macos/setup.sh
```

### Include editor extensions too

```bash
bash macos/setup.sh --with-extensions
```

### If you skipped handoff the first time, rerun with Claude Code handoff

```bash
bash macos/setup.sh --handoff
```

## Troubleshooting

### “Unknown argument”

You probably mistyped a flag. Run:

```bash
bash macos/setup.sh --help
```

### “Homebrew is not available. Cannot continue.”

This usually means the account is not an admin account. Sign in as an admin or give this user admin access, then rerun the script.

### “Permission denied” when running a script

Use `bash ...` in front of the script path instead of double-clicking the file.

### “Config file not found” during OpenClaw setup

Make sure you ran the three `cp shared/config/...` commands from the repo root first.

### OpenClaw service did not start

Run:

```bash
bash shared/scripts/setup-openclaw.sh --check
```

Then read the last `❌` message and rerun the main setup command after fixing it.

## License

MIT
