# OpenClaw Setup Audit

You're comparing this OpenClaw installation against the mac-mini-setup reference template.

## Instructions

1. **Run the audit script** from the mac-mini-setup repo:
   ```bash
   cd ~/projects/mac-mini-setup && ./scripts/audit-openclaw.sh
   ```

2. **Analyze the output** and organize findings into three categories:

### Category 1: Missing — Template has it, you don't
Things the reference template includes that this install is missing. For each:
- What it is and what it does
- Whether it's recommended or optional
- How to add it (exact command or file edit)

### Category 2: Conflicts — Different values
Settings where your install differs from the template. For each:
- What the template recommends vs what you have
- Which is likely better and why
- Whether to change it (some differences are valid customizations)

### Category 3: Your extras — Worth upstreaming?
Things you have that the template doesn't. For each:
- Is it generic enough to benefit other setups?
- If yes, note it as a candidate for the template

## What to compare

### Workspace files (`~/.openclaw/workspace/`)
- Root `.md` files (AGENTS, SOUL, IDENTITY, USER, TOOLS, HEARTBEAT, MEMORY)
- `docs/` — reference docs and playbooks
- `tools/` — tool-specific notes
- `scripts/` — utility scripts

### Config (`~/.openclaw/openclaw.json`)
- Agent defaults (model, heartbeat, workspace)
- Memory config (sources, embeddings, update interval)
- Skills (bundled allowlist, custom entries)
- Plugins (which are enabled)
- Session settings (reset mode, idle timeout)
- Channel configs (structure, not secrets)

### Skills (`~/.agents/skills/` or `~/.openclaw/skills/`)
- Which custom skills are installed
- Which clawhub skills are installed

### Git config
- `git config --global --list` vs recommended defaults

### Cron jobs
- `openclaw cron list` vs recommended periodic tasks

## Output format

Present findings as a clear report with actionable recommendations. Group by category. For each item, include:
- **Status**: MISSING / DIFFERS / EXTRA
- **What**: Brief description
- **Action**: What to do about it (add / change / keep / upstream)
- **Priority**: HIGH (important for functionality) / MEDIUM (nice to have) / LOW (cosmetic)

End with a summary count and ask which items the user wants to act on.
