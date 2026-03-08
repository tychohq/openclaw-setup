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

Paste this into Terminal and press `Return`:

```bash
curl -fsSL https://raw.githubusercontent.com/tychohq/openclaw-setup/main/macos/bootstrap.sh | bash
```

Plain-English explanation:

- `curl` downloads the starter script
- `| bash` runs it

What you should see:

- `Mac Mini Setup — Bootstrap`
- A request for your Mac password

Short alias for the same script:

```bash
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
- Apps like Arc, Chrome, Cursor, Slack, Discord, Raycast, and 1Password
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

## Step 5: Optional preview mode

If you want to review the plan before changing anything:

```bash
git clone https://github.com/tychohq/openclaw-setup.git ~/projects/openclaw-setup
cd ~/projects/openclaw-setup
bash macos/setup.sh --dry-run
```

What you should see:

- `❓` items that would be installed
- `✅` items that are already there

## Step 6: Create your OpenClaw config files

From the repo root, run:

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

## Step 7: Fill in the files

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

## Step 8: Run OpenClaw setup

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

## Step 9: Check your install

```bash
bash shared/scripts/setup-openclaw.sh --check
```

What you should see:

- `✅ openclaw CLI found`
- `✅ Config file exists`
- `✅ OpenClaw installation looks good!`

## Step 10: Optional workspace bootstrap

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

### Run the full Mac setup from a cloned repo

```bash
cd ~/projects/openclaw-setup
bash macos/setup.sh
```

### Include editor extensions too

```bash
bash macos/setup.sh --with-extensions
```

### Start the optional Claude Code handoff at the end

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

## Advanced: Slack bot creation

If you want a Slack bot for OpenClaw, run:

```bash
bash macos/scripts/create-slack-bot.sh <your-config-token> --manifest shared/slack-app-manifest.json
```

## License

MIT
