# TOOLS.md - Local Notes

Short cross-cutting gotchas and environment quirks. Detailed tool docs in `tools/*.md` — searchable via `memory_search`.

## npm Wrapper
`/opt/homebrew/bin/npm` redirects to `bun`. Use `bun install`, `bun install -g <pkg>`. Escape hatch: `npm-real <args>`.

## PDF Generation
`md2pdf` script in `scripts/` converts Markdown → PDF via pandoc + tectonic. See `tools/pdf.md`.

## Scripting
- Prefer bash `.sh` scripts
- Python packages: use `uv` / `uvx` (not pip)
- **SIGPIPE gotcha:** `set -euo pipefail` + `sort | head` → exit 141. Use `set -e` + `trap '' PIPE` for scripts with truncating pipes.

## Brave Search
- Free plan: one request at a time. Sequential searches only.
