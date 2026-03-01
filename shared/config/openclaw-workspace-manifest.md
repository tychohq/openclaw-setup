# OpenClaw Workspace Manifest

What gets bootstrapped onto a new OpenClaw install. The `bootstrap-openclaw-workspace.sh` script handles most of this automatically.

---

## 1. Workspace Root Files

These are injected into every agent session:

| File | Purpose | Action |
|---|---|---|
| `AGENTS.md` | Operating instructions, safety rules, workflow | Customize for your agent |
| `SOUL.md` | Personality, tone, communication style | Customize per agent |
| `IDENTITY.md` | Name, creature, vibe, emoji | Customize |
| `USER.md` | User profile (name, timezone, preferences) | Rewrite per user |
| `TOOLS.md` | Tool gotchas, environment quirks | Mostly generic |
| `MEMORY.md` | Memory index | Generic structure |
| `HEARTBEAT.md` | Active processes to monitor | Starts empty |

## 2. Workspace Subdirectories

### docs/
- `openclaw-playbook.md` — OpenClaw operations guide (platform formatting, scripting, async patterns, browser automation)
- `doc-layers.md` — Progressive-disclosure document conventions (L0-L5 layers)

### tools/
Per-tool reference docs (all generic):
- `async-polling.md` — Background job polling patterns
- `browser.md` — Browser automation (real Chrome vs headless)
- `discord.md` — Discord-specific formatting and conventions
- `docker.md` — Docker usage notes
- `pdf.md` — PDF generation via md2pdf
- `uv-python.md` — Python package management with uv

### scripts/
- `error-digest.sh` — Gateway error log analysis (used by error-log-digest cron)
- `md2pdf.sh` — Markdown → PDF converter (pandoc + tectonic)
- `pre-commit-secrets.sh` — Git pre-commit hook that blocks commits containing API keys

### memory/
- `daily/` — Daily log files (created as needed, YYYY-MM-DD.md format)

---

## 3. Custom Skills (`~/.openclaw/skills/`)

Installed from the repo's `openclaw-skills/` directory:

| Skill | Purpose |
|---|---|
| `answeroverflow` | Search indexed Discord community Q&A |
| `clawdstrike` | Security audit and threat model |
| `cron-setup` | Conventions for creating cron jobs |
| `doc-layers` | Document layer conventions |
| `email` | Gmail via gog CLI |
| `gog` | Google Workspace CLI |
| `self-reflection` | Hourly session review and lesson extraction |
| `system-watchdog` | System resource monitoring |

## 4. ClawHub Skills (`~/.agents/skills/`)

Installed via `clawhub install`:

```bash
clawhub install agent-browser architecture-research caddy commit create-mcp deslop dev-serve diagrams domain-check merge-upstream modal new-brain-dump process-brain-dump research supabase tmux ui-scaffold vercel
```

## 5. Bundled Skills

Controlled by `skills.allowBundled` in `openclaw.json`. Only these bundled skills load:

discord, gemini, github, mcporter, nano-banana-pro, openai-whisper-api, session-logs, skill-creator, tmux, gog, goplaces, healthcheck, nano-pdf, openai-image-gen, slack

All others are excluded.

## 6. Cron Jobs

Template JSON files in `cron-jobs/`:

| Job | Schedule | Purpose |
|---|---|---|
| `self-reflection` | Hourly | Reviews sessions, extracts lessons |
| `system-watchdog` | Daily 4 AM | System health (RAM, CPU, disk, zombies) |
| `daily-workspace-commit` | Daily 4 AM | Local git backup of workspace |
| `error-log-digest` | Daily 8 AM | Gateway error log review |
| `cron-health-watchdog` | Every 6 hours | Monitors cron jobs for failures |

See `cron-jobs/README.md` for installation instructions.

## 7. Git Pre-commit Hook

The `pre-commit-secrets.sh` script scans staged files for common API key patterns (Anthropic, OpenAI, Google, GitHub, AWS, Stripe, etc.) and blocks the commit if any are found. Installed automatically by the bootstrap script into `~/.openclaw/.git/hooks/pre-commit`.

---

## Bootstrap Sequence

1. Run `setup.sh` (installs Homebrew, apps, tools, OpenClaw)
2. Run `scripts/setup-openclaw.sh` (configures OpenClaw with secrets)
3. Run `scripts/bootstrap-openclaw-workspace.sh` (copies all the above)
4. Customize: `USER.md`, `SOUL.md`, `IDENTITY.md`
5. Start gateway: `openclaw gateway start`
6. Create cron jobs (ask agent or use JSON templates)
