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

```bash
curl -fsSL https://raw.githubusercontent.com/tychohq/openclaw-setup/main/macos/bootstrap.sh | bash
```

What this command does:

- `curl` downloads the starter script from GitHub
- `| bash` runs that script immediately

What you should see:

- A box that says `Mac Mini Setup — Bootstrap`
- A message asking for your Mac password
- A message about Apple Command Line Tools if they are not installed yet

Short alias for the same flow:

```bash
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

The Mac setup script prepares the machine. **OpenClaw configuration is the next step**, because the script cannot guess your secret keys.

### 1. Create your three local config files

From the repo root:

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
