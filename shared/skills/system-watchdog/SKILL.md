# System Watchdog

Nightly system resource monitoring. Detects wasteful or suspicious processes and reports only when something needs attention.

## How to Invoke

```bash
bash $HOME/.openclaw/workspace/skills/system-watchdog/check.sh
```

The script outputs JSON to stdout. Parse the output and decide whether to report.

## Output Format

The script outputs a JSON object with:

```json
{
  "suspicious": true|false,
  "system": {
    "ram_used_gb": 12.3,
    "ram_total_gb": 31.2,
    "ram_pct": 39.4,
    "swap_used_gb": 0.5,
    "swap_total_gb": 8.0,
    "swap_pct": 6.3,
    "load_1m": 1.2,
    "load_5m": 0.8,
    "load_15m": 0.6,
    "cpu_cores": 8
  },
  "disk": [
    { "filesystem": "/dev/sda1", "mount": "/", "used_pct": 45, "used_gb": 120, "total_gb": 256 }
  ],
  "issues": [
    {
      "type": "high_ram|high_cpu|zombie|stale|swap|disk",
      "description": "...",
      "details": { ... }
    }
  ],
  "top_processes": [
    { "pid": 1234, "user": "youruser", "name": "claude", "cpu_pct": 2.1, "mem_pct": 14.5, "mem_mb": 4650, "elapsed": "3-02:15:30", "elapsed_human": "3 days" }
  ]
}
```

## Thresholds That Trigger a Report

| Check | Threshold | Issue Type |
|-------|-----------|------------|
| Process RAM | > 4096 MB | `high_ram` |
| Process CPU | > 50% | `high_cpu` |
| Zombie processes | Any | `zombie` |
| Stale processes | Running > 2 days AND cumulative CPU > 10 min | `stale` |
| Swap usage | > 50% of total | `swap` |
| Disk usage | > 80% on any mount | `disk` |

If **any** issue is found, `suspicious` is `true` and a report should be sent.

## Common Offenders

- `claude` — AI coding agent processes left running for days/weeks
- `whisper` / `whisper-server` — speech-to-text servers consuming GPU/RAM
- `python` / `python3` — runaway scripts or leaked processes
- `node` — dev servers or builds that never stopped

## Agent Workflow

1. Run `check.sh`
2. Parse the JSON output
3. If `suspicious` is `false` → do nothing (no message)
4. If `suspicious` is `true` → format a concise report and send via your configured channel

### Report Format

```
⚠️ System Watchdog Report

📊 System: RAM 12.3/31.2 GB (39%) | Swap 0.5/8.0 GB (6%) | Load 1.2/0.8/0.6
💾 Disk: / 45% (120/256 GB)

🔴 Issues Found:

HIGH RAM — claude (PID 1234)
  CPU: 2.1% | RAM: 4650 MB (14.5%) | Running: 3 days
  → Likely stale, safe to kill

ZOMBIE — [defunct] (PID 5678)
  Parent PID: 1230
  → Kill parent or reap

💡 Suggested: kill 1234 5678
```

## Known Issues

- **Intermittent jq parse error:** `check.sh` sometimes fails with "invalid JSON text passed to --argjson" on first run, but succeeds on immediate retry. Likely a race condition where a variable from the process scan is empty/malformed. If the watchdog agent gets this error, retry once before reporting failure.
- **macOS incompatibility:** `check.sh` uses `free` (Linux-only) for RAM/swap stats. On macOS (Mac Mini), this fails with `command not found: free`. The script needs to be adapted to use `sysctl hw.memsize` / `vm_stat` on macOS, or the cron should only be enabled on Linux hosts.
