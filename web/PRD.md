# PRD: OpenClaw Setup Frontend

## Overview
A single self-contained `index.html` that displays the OpenClaw Setup catalog — patches, cron jobs, and skills — letting users browse, select, and download a configuration bundle.

## Architecture
- **Single HTML file** (`web/index.html`) with inline CSS and JS
- **Tailwind CSS via CDN** for styling
- **js-yaml via CDN** for parsing YAML manifests in-browser
- **No framework, no build step, no compilation**
- **Two data modes** (auto-detected):
  - **Local mode:** When URL contains `?local=true`, fetches from relative paths (`../shared/patches/patches/`, `../shared/patches/files/configs/`, etc.) — requires a static file server like `bunx serve`
  - **GitHub mode (default):** Fetches from GitHub API (`https://api.github.com/repos/tychohq/openclaw-setup/contents/...`) using raw content URLs

## Data Sources

### Patches (primary)
- Source: `shared/patches/patches/*.yaml`
- Each YAML file is a patch manifest with: `id`, `description`, `targets`, `created`, `steps[]`
- Steps reference config JSON files in `shared/patches/files/configs/`
- Display: card per patch showing id, description, step types, which config keys it touches

### Config Files (detail view for patches)
- Source: `shared/patches/files/configs/*.json`
- These are the actual config merge payloads
- Display: expandable JSON preview when clicking a patch card

### Cron Jobs
- Source: `shared/patches/files/cron/` (currently empty — `.gitkeep` only)
- Future: will contain cron job definition files
- Display: placeholder section with "Coming soon" or empty state for now

### Skills
- For now: link out to ClawHub (https://clawhub.com)
- Display: section with link/CTA, possibly future API integration

## UI Design

### Layout
- Clean, modern dark theme (OpenClaw brand feel)
- Header with OpenClaw logo/name + "Setup Catalog" title
- Three tab sections: **Patches** | **Cron Jobs** | **Skills**
- Patches tab is the default/primary view

### Patch Cards
Each patch displays:
- **Title** (the patch `id` in human-readable form, e.g. "agent-defaults" → "Agent Defaults")
- **Description** from YAML
- **Tags/badges** for step types (config_patch, exec, restart, etc.)
- **Expandable detail** showing:
  - Full step list
  - JSON config preview (syntax highlighted or formatted)
  - Target deployments
- **Checkbox** for selection

### Selection & Download
- Checkboxes on each patch card
- "Select All" / "Deselect All" buttons
- Floating/sticky "Download Bundle" button (shows count of selected)
- Download generates a JSON file containing:
  - Selected patch manifests
  - Referenced config files (embedded)
  - A `manifest.json` with metadata (timestamp, version, selection list)

### Empty States
- Cron jobs: "No cron job templates yet. Check back soon."
- Skills: "Browse skills on ClawHub →" with link

## File Structure
```
web/
  index.html          # The single self-contained file
  PRD.md              # This file
package.json          # At repo root, with "dev" script
```

## package.json (at repo root)
```json
{
  "name": "openclaw-setup",
  "private": true,
  "scripts": {
    "dev": "bunx serve . -l 3000 -o web/index.html?local=true"
  }
}
```

## Technical Notes

### GitHub API Fetching
```js
// List files in a directory
const res = await fetch('https://api.github.com/repos/tychohq/openclaw-setup/contents/shared/patches/patches');
const files = await res.json(); // [{name, download_url, ...}, ...]

// Fetch raw file content
const yaml = await fetch(file.download_url).then(r => r.text());
const patch = jsyaml.load(yaml);
```

### Local Mode — Directory Listing Problem
Static file servers don't support directory listing via fetch. Solutions:

**Recommended approach:** Maintain a `web/catalog.json` index file that lists all patch filenames. This is trivially auto-generated:

```bash
# scripts/build-catalog-index.sh
cd shared/patches/patches && ls *.yaml | sed 's/.yaml//' | jq -R -s 'split("\n") | map(select(. != ""))' > ../../../web/catalog.json
```

In local mode, the HTML reads `catalog.json` for the file list, then fetches each YAML by relative path. In GitHub mode, it uses the GitHub API for directory listing instead.

We could also have `bun run dev` run this script before starting the server, so it's always fresh.

BUT — even simpler: in GitHub mode we can also use catalog.json from the repo (fetched via raw GitHub URL) so the logic is identical in both modes. The only difference is the base URL for fetches.

### YAML Parsing
```html
<script src="https://cdn.jsdelivr.net/npm/js-yaml@4.1.0/dist/js-yaml.min.js"></script>
```

### JSON Display
Simple `<pre>` with CSS-based syntax coloring. No library needed.

## Design Tokens
- Background: `#0a0a0a` (near-black)
- Cards: `#1a1a2e` with subtle border
- Accent: `#6366f1` (indigo-500)
- Text: `#e5e7eb` (gray-200)
- Badges: color-coded by step type
- Font: system font stack

## Success Criteria
1. `bun run dev` → browser opens → all patches rendered as cards with real data
2. Click patch → expanded config JSON details
3. Select via checkboxes → Download → valid JSON bundle
4. Deploy to GitHub Pages → same experience, fetching from GitHub
5. No build step for production (catalog.json committed to repo)
6. Looks clean on desktop
