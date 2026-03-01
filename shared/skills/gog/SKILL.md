---
name: gog
description: Google Workspace CLI for Gmail, Calendar, Drive, Contacts, Sheets, and Docs.
---

# gog - Google Workspace CLI

## Prerequisites

See [SETUP.md](./SETUP.md) for installation and authentication.

The `GOG_ACCOUNT` env var should be set in OpenClaw config — no need to pass `--account` on every command.

## Calendar: Finding Past Events

**Important:** When looking for historical events (past appointments, previous bookings, etc.), search explicitly with date ranges that include the past:

```bash
# Search today specifically (catches events that already happened today)
gog calendar events primary --from 2026-02-02T00:00:00 --to 2026-02-02T23:59:59

# Search recent past (last 30 days)
gog calendar events primary --from $(date -d '30 days ago' +%Y-%m-%dT00:00:00) --to $(date +%Y-%m-%dT23:59:59)

# Get full event details (including location) with --json
gog calendar events primary --from 2026-02-02T00:00:00 --to 2026-02-02T23:59:59 --json
```

The default `gog calendar list` only shows upcoming events — it won't find events that happened earlier today.

## Calendar: Creating Events

```bash
gog calendar create primary --summary "Event Title" --from "2026-02-16T15:30:00-05:00" --to "2026-02-16T16:30:00-05:00" --location "Address"
```

**Event Colors:** Use `--event-color <id>` (1-11). Run `gog calendar colors` to see the palette.

## Gmail: Searching

```bash
# Recent emails
gog gmail search 'newer_than:7d' --max 10

# Search by sender
gog gmail messages search "from:example.com" --max 20
```

## Gmail: Sending

```bash
# Plain text (use --body-file for multi-line)
gog gmail send --to a@b.com --subject "Subject" --body-file ./message.txt

# From stdin
gog gmail send --to a@b.com --subject "Hi" --body-file - <<'EOF'
Message body here.
EOF
```

**Note:** `--body` does NOT unescape `\n`. For newlines, use `--body-file` with heredoc or a temp file.

## Drive/Sheets/Docs

```bash
gog drive search "query" --max 10
gog sheets get <sheetId> "Tab!A1:D10" --json
gog docs cat <docId>
```

## Tips

- For scripting, use `--json` and `--no-input`
- Confirm before sending mail or creating events
- `gog gmail search` returns threads; `gog gmail messages search` returns individual emails
