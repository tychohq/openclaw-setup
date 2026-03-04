# openclaw-setup

Unified setup monorepo for [OpenClaw](https://github.com/openclaw) — macOS provisioning, AWS deployment, and shared configuration in one place.

## Directory Structure

```
openclaw-setup/
├── aws/              # AWS EC2 deployment (Terraform + setup wizard)
├── macos/            # macOS machine provisioning (Homebrew, apps, dotfiles)
├── shared/           # Shared resources used by both platforms
│   ├── checklist/    # Deployment health check scripts
│   ├── config/       # Config and env templates
│   ├── cron-jobs/    # Cron job JSON definitions
│   ├── patches/      # Declarative patch system (YAML manifests, CLI, tests)
│   ├── scripts/      # Setup, bootstrap, and audit scripts
│   ├── skills/       # Custom OpenClaw skills
│   └── workspace/    # Workspace starter files (SOUL.md, docs, tools, etc.)
└── meta/             # Internal docs, PRDs, reviews, and project notes
```

## Getting Started

**macOS setup:**
```bash
# One-liner bootstrap (or clone and run macos/setup.sh directly)
curl -fsSL mac.brennerspear.com | bash
```
See [macos/](macos/) for details.

**AWS deployment:**
```bash
cd aws && ./setup.sh
```
See [aws/README.md](aws/README.md) for details.

## Post-Deploy Verification

After setup completes, verify the model can respond:

```bash
bash shared/scripts/smoke-test.sh
```

This runs automatically during AWS deployment (Step 11 of `post-clone-setup.sh`) but can be re-run standalone on any platform.

## Secrets

Config templates live in `shared/config/`. Copy them to the repo root, fill in your values:

```bash
cp shared/config/openclaw-config.template.json openclaw-secrets.json
cp shared/config/openclaw-env.template          openclaw-secrets.env
cp shared/config/openclaw-auth-profiles.template.json openclaw-auth-profiles.json
```

These files are gitignored and never committed.

## License

MIT
