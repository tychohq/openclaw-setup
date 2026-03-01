# Setup Context

This machine was set up using the mac-mini-setup script.
Repo: ~/projects/mac-mini-setup

## What the script already did
- Installed Xcode Command Line Tools
- Installed Homebrew + CLI tools (fd, fzf, gh, jq, tmux, uv, etc.)
- Installed GUI apps via Homebrew Cask (see config.sh for full list)
- Installed Bun + global packages (TypeScript, tsx, Vercel CLI)
- Installed Node.js via fnm
- Set up shell aliases and shortcuts (~/.zshrc)
- Created CLI symlinks (subl, code)
- Configured git defaults (init.defaultBranch, pull.rebase, push.autoSetupRemote, fetch.prune, rebase.autoStash)
- Installed global .gitignore_global (DS_Store, node_modules, .env, __pycache__, etc.)
- Applied macOS defaults (dock, Finder, dark mode, etc.)
- Installed OpenClaw + agent-browser + mcporter + clawhub
- Placed OpenClaw config files (openclaw.json, .env, auth-profiles.json)
- Bootstrapped workspace with starter files
- Installed clawhub skills

## Config file locations
- OpenClaw config: `~/.openclaw/openclaw.json`
- Environment vars: `~/.openclaw/.env`
- Auth profiles: `~/.openclaw/agents/main/agent/auth-profiles.json`
- Setup repo: `~/projects/mac-mini-setup/`
- Setup config: `~/projects/mac-mini-setup/config.sh`

## Checking what was installed
Run from the setup repo:
```bash
cd ~/projects/mac-mini-setup
./setup.sh --dry-run    # Shows what's installed vs missing
scripts/setup-openclaw.sh --check   # Verifies OpenClaw config
```

## Installing additional packages
Commented-out packages in config.sh are available but not installed.
Install them directly: `brew install <formula>` or `brew install --cask <app>`
Or uncomment in config.sh and re-run `./setup.sh`
