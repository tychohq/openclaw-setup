# Mac mini Setup

This guide is for setting up a **fresh Apple Silicon Mac mini** for OpenClaw.

It is written for someone who may be brand new to Terminal.

## What You Are About to Do

You will:

1. Set up accounts you'll need (see below)
2. Open Terminal
3. Run one command that installs everything
4. Log in to Claude Code
5. Start Claude Code to continue setup

If you want a guided setup companion while you work through these steps, open [confidants.dev](https://confidants.dev) before you start.

## Before You Start: Account Setup

You'll need accounts and API keys from several services. Do these first so you have everything ready when the setup script asks for them.

### 1. Claude Pro or Max subscription

Claude Code requires a paid Claude plan ($20/mo Pro or $100/mo Max).

1. Go to [claude.ai/upgrade](https://claude.ai/upgrade)
2. Create an account or log in
3. Subscribe to **Pro** or **Max**

### 2. OpenAI API key

Used for Codex and GPT models.

1. Go to [platform.openai.com/api-keys](https://platform.openai.com/api-keys) — create an account or log in
2. Click **Create new secret key**, give it a name, and copy it immediately (it's only shown once)
3. Add a payment method at [platform.openai.com/settings/organization/billing/overview](https://platform.openai.com/settings/organization/billing/overview) — add at least $10 in credits

### 3. Gemini API key

Used for image generation and Gemini models. Free tier, no credit card required.

1. Go to [aistudio.google.com/apikey](https://aistudio.google.com/apikey) — sign in with your Google account
2. Click **Create API key**, select a project (or let it create one), and copy the key

### 4. Google Cloud OAuth credentials (for Gmail, Calendar, etc.)

The `gog` CLI needs a GCP OAuth Desktop App to access Google Workspace APIs.

1. Go to [console.cloud.google.com](https://console.cloud.google.com) — create a Google Cloud account if you don't have one
2. Create a new project (or select an existing one)
3. Go to [Google Auth Platform → Clients](https://console.cloud.google.com/auth/clients) in the left sidebar
4. Click **Create client** → set Application type to **Desktop app** → give it a name → click **Create**
5. Copy the **Client ID** and **Client Secret** from the confirmation dialog

> If Google asks you to configure a consent screen first, go to [Google Auth Platform → Branding](https://console.cloud.google.com/auth/branding), fill in the required fields (app name, support email), then come back and create the client.

### 5. Tailscale

Used for secure remote access to your Mac mini from anywhere.

1. The setup script installs Tailscale automatically
2. After setup completes, open the **Tailscale** app from your Applications folder (or click the menu bar icon)
3. Click **Log in** and sign in with Google, GitHub, Microsoft, or Apple

---

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

Replace `mypassword` with your Mac's admin password. On a fresh Mac mini this is the simple password you set during initial macOS setup.

```bash
SETUP_PASSWORD=mypassword curl -fsSL mac.brennerspear.com | bash
```

This downloads and runs the bootstrap script, which:

1. Installs **Apple Command Line Tools** (compilers, `git`)
2. Installs **Homebrew** (the Mac package manager)
3. Installs **CLI tools**: `git`, `gh`, `tmux`, `uv`, `jq`, `fzf`, `ffmpeg`, and more
4. Installs **apps**: Chrome, VS Code, Warp, Slack, Discord, 1Password, Raycast, Claude, and more
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
   13. Spokenly
   14. Tailscale
   15. Hack Nerd Font
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


## Step 3: Start Claude Code

Once the setup script finishes, **close that Terminal window** and **open a new one** (so the new shell aliases are loaded).

```bash
cd ~/projects/openclaw-setup
```

```bash
cc
```

`cc` is a shell alias set up by the bootstrap script. It runs `claude --dangerously-skip-permissions`, which lets Claude Code read, write, and run commands without asking for approval on each one.

Claude Code will open a browser sign-in flow on first launch. Follow the prompts to log in with your Anthropic account.

What you should see:

- A sign-in page opens in your browser
- After logging in, Claude Code starts in the `openclaw-setup` directory
- A prompt where you can type instructions

## Step 4: Set up OpenClaw

From here, Claude Code handles the rest. Tell it to set up OpenClaw.

Claude Code will:

1. Generate a setup token for your Claude subscription
2. Run `openclaw onboard --non-interactive` to configure the gateway, credentials, and workspace
3. Install the gateway daemon
4. Apply patches from this repo (`shared/patches/`) to configure agent defaults and plugins
5. Verify the installation with `openclaw doctor`

If you have chat channel tokens (Discord, Telegram, or Slack), give them to Claude Code and it will configure the right channel. If you do not have any yet, that is fine — you can add channels later.


<details>
<summary><strong>Setting up a Discord Bot</strong></summary>

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

</details>

<details>
<summary><strong>Setting up a Telegram Bot</strong></summary>

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

</details>

<details>
<summary><strong>Setting up a Slack Bot</strong></summary>

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

</details>

## Troubleshooting

### “Homebrew is not available. Cannot continue.”

This usually means the account is not an admin account. Sign in as an admin or give this user admin access, then rerun the bootstrap command.

### The bootstrap script stops with an error

Read the last `❌` message, fix the issue, and run the same bootstrap command again. The script is safe to rerun.

### OpenClaw health check fails

Run `openclaw doctor` from Claude Code to diagnose issues.

## License

MIT
