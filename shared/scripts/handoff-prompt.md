# Mac Mini Setup — Handoff

You're helping finish setting up a fresh Mac mini. The automated setup script just ran and installed the core tools, apps, and configuration. Now you need to help with the interactive parts that couldn't be automated.

## What the script already did
- Installed Homebrew, CLI tools, and GUI apps (see config.sh for the full list)
- Installed Bun, Node.js (via fnm), and global packages
- Set up shell aliases and shortcuts in ~/.zshrc
- Applied macOS defaults (dock, Finder, dark mode, etc.)
- Created directory structure

## What likely still needs to happen

Check which of these are done and help with the rest:

### 1. CLI Authentication
- `gh auth login` — GitHub CLI
- `vercel login` — Vercel (if using)
- `tailscale up` — Tailscale VPN
- `1password signin` — 1Password CLI

### 2. SSH Keys
- Check if `~/.ssh/id_ed25519` exists
- If not, generate: `ssh-keygen -t ed25519 -C "user@email"`
- Add to ssh-agent: `ssh-add --apple-use-keychain ~/.ssh/id_ed25519`
- Add public key to GitHub: `gh ssh-key add ~/.ssh/id_ed25519.pub`

### 3. Git Config
- `git config --global user.name` — check if set
- `git config --global user.email` — check if set
- `git config --global init.defaultBranch main`
- `git config --global pull.rebase true`

### 4. OpenClaw (if INSTALL_OPENCLAW was true)
- Check if `~/.openclaw/openclaw.json` exists
- If not, help create the config from the templates
- Guide through API key setup (Anthropic, OpenAI, etc.)
- Set up channel tokens (Discord, Telegram, Slack)
- Run `scripts/setup-openclaw.sh --check` to verify

### 5. App Sign-ins (remind the user)
- 1Password
- Raycast (cloud sync handles preferences)
- Slack workspaces
- Discord
- iCloud (System Settings)
- Spotify

### 6. Additional packages
The setup summary below includes items that were commented out in config.sh
(available but not installed). Ask the user if they want any of them installed.
Use `brew install <formula>` or `brew install --cask <cask>` directly.

### Approach
- Start by checking what's already configured (`gh auth status`, `git config --list`, check for SSH keys, etc.)
- Show the user what was installed, what failed, and what's available but skipped
- Ask what they want to tackle first
- Be efficient — skip what's already done
- For OpenClaw, walk through each API key they need
