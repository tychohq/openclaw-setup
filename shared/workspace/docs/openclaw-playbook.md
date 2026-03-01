# OpenClaw Playbook: Custom Patterns & Lessons

**L1 Tagline:** Battle-tested patterns for production OpenClaw workflows — sub-agent orchestration, memory systems, and platform-specific optimizations.

**L2 Brief:** This playbook captures custom additions beyond the default OpenClaw templates: advanced delegation patterns, model selection strategies, platform-specific formatting, memory management, async job handling, and hard-learned lessons from real usage. No basic setup — only the power-user patterns that aren't documented elsewhere.

## Context Safety & Performance

### Large File Protection
**Never blow up your context window by loading huge files:**

```bash
# ❌ DON'T: Load entire session history
sessions_history

# ✅ DO: Use limits
sessions_history limit: 10

# ❌ DON'T: Read raw transcript JSONL files (can be 100k+ tokens)
Read file_path: "sessions/transcript.jsonl"

# ✅ DO: Use Read with limit and offset for large files
Read file_path: "large-log.txt" limit: 50 offset: 1000
```

**Rule:** Start small, read more if needed. You can't un-read a file that overflows your context.

### Scripting Conventions
**Prefer bash for simplicity, use modern Python tooling:**

```bash
# ✅ Python packages without venv hell
uv run --with pymupdf python3 script.py
uvx --with requests python3 fetch.py

# ✅ Executable scripts (no extension needed for bin CLIs)
#!/bin/bash
# File: bin/deploy (no .sh extension)
```

## Task Delegation & Sub-Agent Orchestration

### Default Delegation Pattern
**Don't work inline — spawn sub-agents for everything substantial:**

```
1. User requests task
2. Spawn sub-agent with clear label/description
3. Acknowledge briefly ("On it — spinning up sub-agent")
4. Sub-agent either:
   - Reports back with results (quick tasks)
   - Posts to your preferred channel (complex tasks)
```

### Sub-Agent Conventions

**Labels:** kebab-case descriptive names
```bash
sessions_spawn label: "update-agents-delegation" task: "..."
sessions_spawn label: "research-flights-miami" task: "..."
```

**Task descriptions must include:**
- All context needed (don't make sub-agent re-read conversation)
- Repo workflow instructions (branching, commit conventions)
- Output routing instructions (which forum topic, specific channels)

**Critical rules:**
- **Never `--no-verify`** — fix the underlying pre-commit issue instead
- **Read repo's AGENTS.md/CONTRIBUTING.md first**
- **Parallel repo work = separate temp dirs** to avoid race conditions:
  ```bash
  git clone ~/projects/project /tmp/project-agent-1
  git clone ~/projects/project /tmp/project-agent-2
  ```

## Memory & State Management

### Progressive Memory System
```
memory/
├── YYYY-MM-DD.md           # Daily raw logs
├── about-user.md           # Curated user info (MAIN SESSION ONLY)
├── future-projects.md      # Ideas and dreams
└── heartbeat-state.json    # Tracking periodic check timestamps
```

**Write everything down — "mental notes" don't survive session restarts.**

### Heartbeat Optimization
**Batch periodic checks to reduce API calls:**

```markdown
# HEARTBEAT.md
## Rotate Through (2-4 times daily):
- Email: urgent unread messages?
- Calendar: events next 24-48h?
- Weather: relevant for user's day?

## Track in memory/heartbeat-state.json:
{"lastChecks": {"email": 1703275200, "calendar": 1703260800}}

## Proactive work (no permission needed):
- Organize memory files
- Review and update MEMORY.md
- Check project status (git status)
- Commit your own documentation changes
```

**Heartbeat vs Cron:**
- **Heartbeat:** Multiple checks batched together, timing can drift
- **Cron:** Exact timing, isolated execution, specific delivery channels

## Document-First Workflow

### Progressive Disclosure Layers
Every significant output gets multiple zoom levels:

| Layer | Name | ~Length | Purpose |
|-------|------|---------|---------|
| **L0** | Title | 3-8 words | Quick identification |
| **L1** | Tagline | 15-25 words | Key insight/recommendation |
| **L2** | Brief | 75-150 words | Executive summary |
| **L3** | Summary | 400-600 words | Structured overview |
| **L4** | Report | 1,500-3,000 words | Detailed analysis |
| **L5** | Deep Dive | Full length | Complete documentation |

**Delivery pattern:** Chat gets L2 Brief + PDF attachment. Full docs live in workspace.

## Platform-Specific Formatting

### Discord
```markdown
# ❌ DON'T: Markdown tables (render poorly)
| Col 1 | Col 2 |
|-------|-------|
| Data  | Data  |

# ✅ DO: Bullet lists
**Results:**
• Item 1: Details here
• Item 2: More details

# ✅ Suppress link embeds when posting multiple URLs
<https://example1.com>
<https://example2.com>
```

### WhatsApp
```markdown
# ❌ DON'T: Headers (not supported)
## Section Title

# ✅ DO: Bold or CAPS for emphasis
**SECTION TITLE**
IMPORTANT REMINDER
```

## Tool-Specific Patterns

### Browser Automation
**Use `agent-browser` for JS-rendered sites:**

```bash
agent-browser open "https://dynamic-site.com"
agent-browser snapshot                    # Get refs
agent-browser click @e2                   # Click element
agent-browser get text @e1                # Extract text
agent-browser screenshot result.png
agent-browser close
```

### Vercel CLI Best Practice
```bash
# ❌ DON'T: echo adds trailing newline
echo "secret_value" | npx vercel env add SECRET production

# ✅ DO: printf for clean values
printf 'secret_value' | npx vercel env add SECRET production
```

### Async Job Polling
**Never block conversation with inline polling loops:**

```bash
# ✅ Background script pattern
exec background=true:
while true; do
  STATUS=$(check_job_status $JOB_ID)
  if [ "$STATUS" = "complete" ]; then
    download_result $JOB_ID /tmp/result.mp4
    send_result /tmp/result.mp4
    break
  fi
  sleep 10
done
```

## Development Workflow

### File Safety
```bash
# ✅ Recoverable deletion
trash file.txt

# ❌ Permanent deletion
rm file.txt
```

### Confidence Markers
Use visual indicators for varying certainty:
- 🔴 Low confidence, needs verification
- 🟡 Medium confidence, likely correct
- 🟢 High confidence, verified

### Vite + Tailscale Config
```typescript
// vite.config.ts
export default defineConfig({
  server: {
    allowedHosts: ['your-hostname.tailnet.ts.net']
  }
});
```
Required when accessing dev servers via Tailscale hostnames.

## Communication Patterns

### Voice Storytelling
**Use TTS for engaging content:**
```bash
# Use 'sag' (ElevenLabs) for stories, summaries, funny voices
sag -v "Nova" "Here's what happened next..."
```

### Group Chat Etiquette
**Quality over quantity — don't respond to every message:**

**Respond when:**
- Directly mentioned or asked
- Can add genuine value
- Correcting important misinformation

**Stay silent when:**
- Casual banter between humans
- Someone already answered
- Would just be "nice" or "yeah"

**Use reactions for lightweight acknowledgment:** 👍 ❤️ 😂 🤔

## Image Handling

**Always use `message` tool for images, don't rely on MEDIA: lines:**

```bash
# ✅ Reliable image delivery
message action: send
        channel: YOUR_CHANNEL
        target: YOUR_TARGET_ID
        filePath: /path/to/image.png
        caption: "Screenshot results"

# ❌ Unreliable
echo "MEDIA: /path/to/image.png"
```

## PDF Generation

**Pandoc + Tectonic for MD→PDF conversion (single command):**

```bash
pandoc input.md --pdf-engine=tectonic -V geometry:margin=1in -V fontsize=11pt -V 'mainfont=Avenir Next' -V monofont=Menlo -o output.pdf
```

Both `pandoc` and `tectonic` are installed via Homebrew. No intermediate HTML step needed. Uses Avenir Next (body) + Menlo (code).

## Lessons Learned

### Critical Mistakes to Avoid
1. **Never load raw JSONL transcripts** — they can be 100k+ tokens
2. **Don't over-clean wishlists** — humans like their organized chaos
3. **Write lessons to files immediately** — session memory is ephemeral
4. **Isolate parallel repo work** — separate temp dirs prevent merge conflicts
5. **Use printf not echo** for env vars — trailing newlines break secrets

### Known Bugs

**`RangeError: Invalid string length` on `config.get`**
Empty string API keys in `openclaw.json` (e.g. `"OPENAI_API_KEY": ""`) cause `redactRawText()` to call `replaceAll("")`, which explodes the config string exponentially (~5KB → 19GB in 5 passes → crash). Gateway runs but config/status endpoints fail.

**Fix:** Remove all empty-string sensitive fields:
```bash
openclaw config unset env.vars.OPENAI_API_KEY
openclaw config unset env.vars.ANTHROPIC_API_KEY
# ... any other empty key/token fields
openclaw gateway stop && openclaw gateway start
```

**Prevention:** Don't leave empty `""` values for API keys or tokens in config. Either set a real value or remove the field entirely.

### Success Patterns
1. **Default to delegation** — sub-agents keep main session responsive
2. **Batch heartbeat checks** — more efficient than individual cron jobs
3. **Layer all documents** — progressive disclosure serves different needs
4. **Background job polling** — don't block conversation for long-running tasks
5. **Platform-specific formatting** — respect each channel's constraints

---

*This playbook captures patterns that work in practice. Add your own as you discover what works for your workflows.*