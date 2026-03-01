# Bootstrap TODO

Work through these items to finish setting up this machine. Check them off as you go.
Ask the user about each unchecked item — don't skip anything.

## 1. CLI Authentication
- [ ] `gh auth login` — GitHub CLI
- [ ] `vercel login` — Vercel CLI (if using)
- [ ] `tailscale up` — Tailscale VPN (if using)

## 2. SSH Keys
- [ ] Generate SSH key: `ssh-keygen -t ed25519 -C "user@email"`
- [ ] Add to agent: `ssh-add --apple-use-keychain ~/.ssh/id_ed25519`
- [ ] Add to GitHub: `gh ssh-key add ~/.ssh/id_ed25519.pub`

## 3. Git Config
The setup script already configured: `init.defaultBranch main`, `pull.rebase true`, `push.autoSetupRemote true`, `fetch.prune true`, `rebase.autoStash true`, and a global `.gitignore_global`.
- [ ] Set your name: `git config --global user.name "Your Name"` (skip if set in config.sh)
- [ ] Set your email: `git config --global user.email "your@email.com"` (skip if set in config.sh)

## 4. API Keys & Auth Profiles
- [ ] Anthropic API key (or Max Plan token) in auth-profiles.json
- [ ] OpenAI API key (if using)
- [ ] OpenRouter API key (if using)
- [ ] Gemini API key (for memory search embeddings)
- [ ] Brave Search API key (for web search)
- [ ] Verify: `scripts/setup-openclaw.sh --check` from mac-mini-setup repo

## 5. Channel Setup
- [ ] Discord bot connected and responding (if using)
- [ ] Telegram bot connected (if using)
- [ ] Slack bot connected (if using)

## 6. App Sign-ins
- [ ] 1Password — sign in and enable browser extension
- [ ] Raycast — sign in (cloud sync handles preferences)
- [ ] Slack — sign into workspaces
- [ ] Discord — sign in
- [ ] Tailscale — approve device
- [ ] iCloud — System Settings → Apple ID
- [ ] Spotify — sign in

## 7. OpenClaw Workspace
- [ ] Customize `USER.md` with your info
- [ ] Customize `IDENTITY.md` with your agent's name/personality
- [ ] Customize `SOUL.md` with communication style
- [ ] Review `AGENTS.md` and adjust rules as needed
- [ ] Set up recommended cron jobs (self-reflection, system-watchdog, error-log-digest)

## 8. Optional
- [ ] Clone your project repos to ~/projects/
- [ ] Set up any additional brew packages (check config.sh for commented-out options)
- [ ] Configure macOS settings not covered by defaults (trackpad, keyboard, etc.)
- [ ] Set up Time Machine backup

## 9. Cleanup
- [ ] Delete this bootstrap folder: `rm -rf ~/.openclaw/workspace/bootstrap`
- [ ] Remove the bootstrap reference from AGENTS.md
