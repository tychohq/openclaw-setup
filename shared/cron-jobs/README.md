# Cron Job Templates

Ready-to-use cron job definitions for OpenClaw. These are starter templates — adjust schedules, models, and delivery channels to match your setup.

## How to Install

After OpenClaw is running, you can add these jobs via the OpenClaw API or by having your agent create them. The JSON files in this directory can be used as references.

**Via your agent:**
Ask your agent to "set up the starter cron jobs from the mac-mini-setup repo" and point it at these files.

**Via the cron tool:**
Each `.json` file contains a job definition ready to pass to `cron add`.

## Included Jobs

| Job | Schedule | What It Does |
|-----|----------|-------------|
| `self-reflection` | Hourly | Reviews recent sessions, extracts lessons learned, writes insights to workspace files |
| `system-watchdog` | Daily 4 AM | Checks system resources (RAM, CPU, disk, zombies), alerts only when something's wrong |
| `daily-workspace-commit` | Daily 4 AM | Git commits workspace changes locally for backup/history |
| `error-log-digest` | Daily 8 AM | Reviews gateway error logs, diagnoses issues, proposes fixes |
| `cron-health-watchdog` | Every 6 hours | Monitors cron jobs themselves — alerts if any job has 3+ consecutive failures |

## Customization

- **Schedule:** All jobs use `America/New_York` timezone — change `tz` to yours
- **Model:** Templates use `anthropic/claude-sonnet-4-20250514` for most jobs. Upgrade to Opus for better quality, or use a cheaper model if cost matters
- **Delivery:** Jobs default to `"mode": "none"` (silent unless they find something to report). Configure `channel` and `to` for your messaging setup
- **Timeouts:** Conservative defaults. Increase `timeoutSeconds` if jobs time out regularly

## Adding Your Own

See the `cron-setup` skill in `openclaw-skills/` for conventions and patterns.
