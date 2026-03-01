---
name: cron-setup
description: Create and manage OpenClaw cron jobs following our conventions. Use when setting up periodic tasks, reminders, automated checks, or any scheduled work.
---

# Cron Job Setup

Our conventions for creating cron jobs in OpenClaw.

## Default Settings

| Setting | Default | Why |
|---------|---------|-----|
| **Model** | `anthropic/claude-sonnet-4-20250514` | Good enough for most automated tasks |
| **Session** | `isolated` | Cron jobs run in their own session, not the main chat |
| **Delivery** | `"mode": "none"` | Job handles its own output (posts to your channel, etc.) |
| **Timeout** | 120-180s | Most jobs should finish fast |

## When to Use a Different Model

| Scenario | Model | Why |
|----------|-------|-----|
| Default | `anthropic/claude-sonnet-4-20250514` | Good enough for most automated tasks |
| Complex multi-step | `anthropic/claude-opus-4-6` | When tasks need real reasoning |

## Job Template

```json
{
  "name": "descriptive-kebab-case-name",
  "schedule": {
    "kind": "cron",
    "expr": "*/30 * * * *",
    "tz": "America/New_York"
  },
  "sessionTarget": "isolated",
  "payload": {
    "kind": "agentTurn",
    "message": "TASK INSTRUCTIONS HERE",
    "model": "anthropic/claude-sonnet-4-20250514",
    "timeoutSeconds": 120
  },
  "delivery": {
    "mode": "none"
  }
}
```

## Schedule Patterns

| Pattern | Cron Expression | Notes |
|---------|----------------|-------|
| Every 30 min | `*/30 * * * *` | Good for inbox checks, monitoring |
| Every hour | `0 * * * *` | Self-reflection, status checks |
| Daily at 4 AM | `0 4 * * *` | Cleanup, backups (during quiet hours) |
| Daily at 6 AM | `0 6 * * *` | Morning digests, daily summaries |
| Weekly Monday 2 PM | `0 14 * * 1` | Weekly outreach, reviews |
| One-shot | Use `"kind": "at"` instead | Reminders, one-time tasks |

## Task Instruction Conventions

1. **Be explicit with commands** — Give the cron agent exact bash commands to run. It doesn't have our context.
2. **Include skip conditions** — If there's nothing to do, the agent should reply `SKIP` to avoid wasting tokens.
3. **Handle its own output** — The job should post results to your configured channel using the `message` tool directly. Don't rely on delivery mode for formatted output.
4. **Include error handling** — What should happen if a command fails?
5. **Keep instructions self-contained** — The cron agent wakes up with no context. Everything it needs should be in the task message.

## Posting from Cron Jobs

When a cron job needs to notify you, include these instructions in the task:

```
Post using the message tool:
- action: send
- channel: YOUR_CHANNEL (e.g., discord, telegram, slack)
- target: YOUR_TARGET_ID
- message: Your formatted message
```

Configure the channel and target to match your setup.

## Delivery Modes

| Mode | When to Use |
|------|------------|
| `"mode": "none"` | Job posts its own output via the `message` tool (most common) |
| `"mode": "announce"` | OpenClaw auto-delivers the agent's final message to a channel. Use when output IS the message (e.g., daily digest). Set `"channel"` and `"to"` to your target. |

## Anti-Patterns

❌ **Don't use heartbeat** for things that can be a cron job. Heartbeat runs in the main session and costs more.
❌ **Don't create cron jobs that loop/poll** — each run should be a single check. If you need polling, use a background exec script instead.
❌ **Don't set delivery mode to "announce"** and also have the job post to a channel — you'll get duplicate messages.

## Checking Current Jobs

Use the `cron list` tool to see all configured jobs anytime.
