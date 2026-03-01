---
name: email
description: Draft, send, search, and manage emails via Gmail using gog CLI. Use when the user wants to compose emails, create drafts, search inbox, reply to threads, find contact emails, or manage Gmail labels.
---

# Email Skill (gog CLI)

## Prerequisites

`GOG_ACCOUNT` env var should be set in OpenClaw config.

## Finding Email Addresses

Search contacts first, then fall back to Gmail search:

```bash
# Search contacts
gog contacts search "Name" --json

# Fall back: search emails from/to that person
gog gmail search "from:name OR to:name" --max 10 --json
```

## Searching Emails

```bash
# Recent emails
gog gmail search 'newer_than:7d' --max 10

# By sender
gog gmail search "from:example@gmail.com" --max 20

# Unread
gog gmail search "is:unread" --max 10

# With attachment
gog gmail search "has:attachment newer_than:30d" --max 10

# Specific subject
gog gmail search 'subject:"meeting notes"' --max 10
```

Use `--json` for scripting.

## Reading Emails

```bash
# Get thread details
gog gmail get <messageId> --json

# Get full message with body
gog gmail get <messageId> --format full
```

## Creating Drafts

**Important:** Use `--body-file` with heredoc or temp file for multi-line bodies. `--body` does NOT interpret `\n`.

```bash
# Create temp file for body
cat << 'EOF' > /tmp/email-body.txt
Hi [Name],

Your message here.

Best,
[Sender]
EOF

# Create draft
gog gmail drafts create \
  --to "recipient@example.com" \
  --cc "cc@example.com" \
  --subject "Subject Line" \
  --body-file /tmp/email-body.txt
```

### Draft with attachment

```bash
gog gmail drafts create \
  --to "recipient@example.com" \
  --subject "Document attached" \
  --body-file /tmp/email-body.txt \
  --attach /path/to/file.pdf
```

## Sending Emails

⚠️ **Always confirm with user before sending.**

```bash
gog gmail send \
  --to "recipient@example.com" \
  --subject "Subject" \
  --body-file /tmp/email-body.txt
```

### Reply to thread

```bash
# Reply to specific message (auto-threads)
gog gmail send \
  --reply-to-message-id "<messageId>" \
  --to "recipient@example.com" \
  --subject "Re: Original Subject" \
  --body-file /tmp/reply.txt

# Reply-all
gog gmail send \
  --reply-to-message-id "<messageId>" \
  --reply-all \
  --subject "Re: Original Subject" \
  --body-file /tmp/reply.txt
```

## Managing Drafts

```bash
# List drafts
gog gmail drafts list

# Get draft
gog gmail drafts get <draftId>

# Send existing draft
gog gmail drafts send <draftId>

# Delete draft
gog gmail drafts delete <draftId>
```

## Labels

```bash
# List labels
gog gmail labels list

# Add label to thread
gog gmail thread modify <threadId> --add-labels "Label Name"

# Remove label
gog gmail thread modify <threadId> --remove-labels "INBOX"
```

## Best Practices

1. **Draft first** — Create drafts for user review before sending
2. **Find contacts** — Search contacts/emails to get correct addresses
3. **Use temp files** — Always use `--body-file` for multi-line content
4. **Confirm sends** — Never send without explicit user approval
5. **JSON for parsing** — Use `--json` when you need to extract data programmatically
