# AGENTS.md — openclaw-setup

## What This Repo Is
Setup scripts and config templates for deploying OpenClaw on new machines.
- `aws/` — EC2 deployment (Terraform + cloud-init)
- `macos/` — Mac mini local setup (Homebrew + shell scripts)
- `shared/` — Config templates, workspace files, and patches shared across platforms
- `meta/` — PRDs and project planning

## Golden Rule: CLI First
**Always use `openclaw` CLI commands over direct file edits.** The CLI validates inputs, prevents malformed config, and handles side effects (restarts, migrations, etc.).

When unsure about a command, look it up:
```bash
openclaw docs <query>          # Semantic search over live docs
openclaw <command> --help       # Authoritative flag reference
```

## CLI Cheatsheet

### Config (safe reads/writes with schema validation)
```bash
openclaw config get <dot.path>                     # Read any config value
openclaw config set <dot.path> <value>             # Write (validates against schema)
openclaw config unset <dot.path>                   # Remove a key
```

### Models
```bash
openclaw models set <model-id>                     # Set default model
openclaw models set-image <model-id>               # Set image model
openclaw models aliases add <alias> <model-id>     # Add alias (e.g. "opus")
openclaw models fallbacks add <model-id>           # Add to fallback chain
openclaw models auth add                           # Interactive auth profile setup
openclaw models auth paste-token --provider <p>    # Paste a setup-token (Max Plan)
openclaw models scan                               # Scan OpenRouter free models
openclaw models status                             # Show current model config
```

### Channels
```bash
openclaw channels add --channel <type> [--token <t>]  # Add channel (discord, telegram, slack, etc.)
openclaw channels list                                 # Show configured channels
openclaw channels status                               # Check channel health
openclaw channels remove --channel <type>              # Remove a channel
```

### Plugins
```bash
openclaw plugins list                              # Discover available plugins
openclaw plugins install <path|npm-spec>           # Install a plugin
openclaw plugins enable <id>                       # Enable
openclaw plugins disable <id>                      # Disable
openclaw plugins doctor                            # Report load errors
```

### Secrets
```bash
openclaw secrets configure                         # Interactive setup (provider + refs)
openclaw secrets audit                             # Check for plaintext leaks
openclaw secrets reload                            # Hot-reload secret refs
```

### Health & Diagnostics
```bash
openclaw doctor                                    # Health checks
openclaw doctor --fix                              # Auto-fix common issues
openclaw status                                    # Channel health + recent sessions
openclaw health                                    # Gateway health endpoint
```

### Setup & Onboarding
```bash
openclaw setup                                     # Init config + workspace
openclaw onboard                                   # Interactive wizard
openclaw onboard --non-interactive --auth-choice <c> --anthropic-api-key <k>  # Scripted setup
openclaw configure --section <s>                   # Re-run specific wizard section
```

### Gateway
```bash
openclaw gateway start                             # Start as daemon
openclaw gateway stop                              # Stop
openclaw gateway restart                           # Restart (picks up config changes)
openclaw gateway install                           # Install as system service
```

### Memory
```bash
openclaw memory status                             # Index stats
openclaw memory index                              # Reindex
openclaw memory search "<query>"                   # Semantic search
```

## When Direct File Edits Are Acceptable
Some things don't have CLI equivalents yet:
- **Workspace files** (`shared/workspace/`) — these are templates, not live config
- **Shell scripts** (`macos/`, `aws/`) — the setup scripts themselves
- **Complex nested config** — e.g. full Discord groups+topics blocks or OpenRouter provider model arrays may be easier as template JSON than a dozen `config set` calls

Even then, prefer generating the config programmatically and applying via `openclaw config set` where possible.

## Docs Reference
- CLI index: https://docs.openclaw.ai/cli/index
- Config reference: https://docs.openclaw.ai/gateway/configuration-reference
- Full docs (LLM-friendly): https://docs.openclaw.ai/llms.txt
- Config guide (in-repo): `shared/workspace/docs/config-guide.md`

## Linear Integration
All OpenClaw Platform work is tracked in Linear (workspace: Tycho, team: `TYC`).

**CLI:**
```bash
L=~/.openclaw/workspace/bin/linear
$L issues list --project "OpenClaw Platform"    # all platform tickets
$L issues read TYC-30                           # full issue details + description
$L issues update TYC-30 --status "In Progress"  # update status
$L comments create TYC-30 --body "Update"       # add comment
```

**Workflow for each ticket:**
1. `$L issues read TYC-XX` — read the issue and understand what's needed
2. Create branch: `git checkout -b tyc-XX-short-description` (Linear auto-links PRs)
3. Do the work, commit, push, open PR
4. Linear auto-moves to "In Progress" on branch push, "Done" on merge

**Project structure:**
| Initiative | Project | What |
|---|---|---|
| OpenClaw Platform | OpenClaw Platform | Cross-cutting infra (config.patch, skill installs, cron, upgrades) |
| OpenSesame | Don's / Aaron's OpenClaw | Client-specific setup |
| Clay | Tess's / Yash's OpenClaw | Client-specific setup |
| Side Projects | Clipper, Exfoliate, Right Hands, SkillDock, Agentic Software Factory | Side projects |

**Labels:** `axel` (agent can do), `brenner` (needs Brenner), `blocker` (cross-cutting)

**Full reference:** `~/.openclaw/workspace/tools/linear.md`

## Authentication: Device Auth Flows
**Never ask the user to log in from a CLI prompt or paste credentials.** When any tool needs auth, run the command with `--no-browser` or equivalent, extract the URL + code, and send them to the user.

| Tool | Command | Notes |
|---|---|---|
| AWS SSO | `aws sso login --profile <p> --no-browser --use-device-code` | Send URL + code; pre-fill link if SSO portal supports `/start/#/device/CODE` |
| Google (gog) | `gog auth add <email> --remote` | Outputs OAuth URL |
| GitHub | `gh auth login` | Outputs device code |
| Codex | `codex login --device-auth` | ChatGPT-backed auth |

Full reference for deployed instances: `shared/workspace/docs/aws.md`

## Rules
- Shell scripts: `set -e`, bash, no exotic deps
- Never write secrets to tracked files — use `.env` (gitignored) or `openclaw secrets`
- Test config changes: `openclaw doctor` after any modification
- Keep templates in `shared/config/` and workspace files in `shared/workspace/`
