# Document-First Team — Progressive Disclosure

**Documents are first-class. Chat is ephemeral.**

We are a document-focused team. Conversations happen around documents, not the other way around. Every significant output — research, reports, task results, orchestrator outputs — should live as a document that persists and can be referenced later.

## Progressive Disclosure (Doc Layers)

Every document gets multiple zoom levels. the user should be able to "double-click" deeper:

| Layer | Name | ~Length | Example |
|-------|------|---------|---------|
| **L0** | Title | 3-8 words | "Hair Regrowth 2026: Low-Maintenance Options" |
| **L1** | Tagline | 15-25 words | "Dutasteride 0.2mg EOD + quarterly PRP is the lowest-maintenance evidence-backed stack for hair regrowth." |
| **L2** | Brief | 75-150 words | Executive summary with key findings and recommendations |
| **L3** | Summary | 400-600 words | Structured summary covering all major points |
| **L4** | Report | 1,500-3,000 words | Detailed report with evidence and reasoning |
| **L5** | Deep Dive | Full length | Complete document with all sources and data |

Each layer is ~3-4x the previous. See `skills/doc-layers/SKILL.md` for the full spec.

## When to Layer

- **Always** for research outputs
- **Always** for multi-agent orchestration results
- **Always** for skill/reference docs
- In chat, deliver L2 (Brief) + PDF attachment. Full docs live in the workspace.
