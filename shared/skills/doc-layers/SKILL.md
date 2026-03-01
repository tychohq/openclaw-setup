# Doc Layers Skill

**Description:** Generate progressive-disclosure document layers for any research, report, or task output. Documents are first-class; chat is ephemeral context around them.

## Philosophy

The user and agent are a **document-focused team**. Every significant output should exist as a document with multiple zoom levels, so the user can drill down as deep as he wants.

## The Layers

Every document gets these layers, from shortest to longest:

| Layer | Name | Target Length | Purpose |
|-------|------|---------------|---------|
| **L0** | Title | 3-8 words | What is this? At a glance. |
| **L1** | Tagline | 15-25 words | One-sentence summary. Enough to decide if you care. |
| **L2** | Brief | 75-150 words | Executive summary. Key findings, recommendations, actions. |
| **L3** | Summary | 400-600 words | Full summary with structure. All major points covered. |
| **L4** | Report | 1,500-3,000 words | Detailed report. Evidence, analysis, recommendations with reasoning. |
| **L5** | Deep Dive | Full length | Complete document. All sources, data, methodology, appendices. |

Each layer is roughly **3-4x** the previous one.

## File Structure

For any document topic, create:

```
research/<topic-slug>/
├── layers.md          # All layers in one file (L0-L3), easy to scan
├── report.md          # L4 — The detailed report
├── deep-dive.md       # L5 — Full research/raw output
└── report.pdf         # PDF export of report.md (when requested)
```

### layers.md Format

```markdown
# <L0: Title>

> <L1: Tagline — one sentence>

---

## Brief

<L2: 75-150 words>

---

## Summary

<L3: 400-600 words>

---

*Full report: [report.md](./report.md) | Deep dive: [deep-dive.md](./deep-dive.md)*
```

## When to Generate Layers

- **Always** for research tasks (Parallel AI deep research, web research, etc.)
- **Always** for orchestrated multi-agent task outputs
- **Always** for skill/reference documents
- **On request** for one-off lookups or simple answers

## How to Generate

### Bottom-up (from raw output):
1. Save the full output as `deep-dive.md` (L5)
2. Write the detailed report as `report.md` (L4) — distill, organize, add structure
3. Generate `layers.md` with L0-L3 by progressively condensing

### Model Selection for Condensing:
- **L5 → L4** (deep dive → report): Use a strong model (Opus or Sonnet) — needs judgment about what matters
- **L4 → L3** (report → summary): Mid-tier is fine (Sonnet)
- **L3 → L2 → L1 → L0**: Can be done by any model, even inline

### Delivery:
When delivering to chat:
1. Send L2 (Brief) as the chat message
2. Attach `report.pdf` if PDF was generated
3. Mention where the full docs live

## Integration with Other Skills

### Research Skill
After Parallel AI completes:
1. Save raw output → `deep-dive.md`
2. Generate all layers
3. Deliver L2 to chat + PDF attachment

### Orchestrator Outputs
After multi-agent tasks complete:
1. Compile all sub-agent reports → `deep-dive.md`
2. Generate all layers
3. Deliver L2 to chat with links to full report

## Retroactive Application

For existing documents that don't have layers yet, generate them on demand:
```
"Layer up the hair regrowth research"
"Add layers to the Vercel speed report"
```

## Trigger

Activate when:
- Any research task completes
- Any multi-agent orchestration finishes
- User says "layer this", "summarize at all levels", "doc layers"
- Delivering any report longer than ~500 words
