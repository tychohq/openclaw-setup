# macOS setup profiles

This repo has separate laptop and always-on Mac Mini profiles.

## Laptop

`mac.brennerspear.com` is reserved for `bootstrap-laptop.sh`, but the endpoint rollout is still pending. Until it is live, deliver the pre-merge installer from a pushed commit SHA so both the downloaded bootstrap and the fetched repo are immutable:

```bash
INSTALL_REF=<40-character-commit-sha>
curl -fsSL "https://raw.githubusercontent.com/tychohq/openclaw-setup/${INSTALL_REF}/macos/bootstrap-laptop.sh" \
  | OPENCLAW_SETUP_REF="$INSTALL_REF" bash
```

Preview safely before any admin, Command Line Tools, filesystem, git, or network work:

```bash
curl -fsSL "https://raw.githubusercontent.com/tychohq/openclaw-setup/${INSTALL_REF}/macos/bootstrap-laptop.sh" \
  | OPENCLAW_SETUP_REF="$INSTALL_REF" bash -s -- --dry-run
```

Add developer applications and utilities with `--technical`. Other `setup.sh` arguments are forwarded unchanged:

```bash
curl -fsSL "https://raw.githubusercontent.com/tychohq/openclaw-setup/${INSTALL_REF}/macos/bootstrap-laptop.sh" \
  | OPENCLAW_SETUP_REF="$INSTALL_REF" bash -s -- --technical
```

The default laptop applications are exactly Google Chrome, 1Password, Raycast, Notion, Zoom, Spokenly, ChatGPT, Warp, and 1Password CLI. Foundations include Xcode Command Line Tools, Homebrew, Bun, Node 24/npm through fnm, uv, Python, Claude Code, Codex CLI, and `mas`.

The laptop setup adds one managed, idempotent block to `~/.zshrc` so new terminals load Homebrew, fnm/Node/npm/Codex, Bun, and `~/.local/bin`. That block contains no aliases, prompt changes, themes, or other personal shell preferences.

`--technical` adds VS Code, Docker Desktop, Sublime Text, Hack Nerd Font, the existing developer CLI utilities, and TypeScript/tsx/Vercel tooling.

The laptop profile deliberately omits Slack, Discord, remote-access apps, OpenClaw, Hermes, handoff, shell aliases, git defaults, and all Dock/Finder/global/screenshot/hotkey/sleep/update/SSH/Screen Sharing changes.

Advanced fetch overrides:

- `OPENCLAW_SETUP_REPO_URL` selects a fork.
- `OPENCLAW_SETUP_REF` selects a branch, tag, or preferably a full commit SHA.
- `OPENCLAW_SETUP_CLONE_DIR` selects the local fetch cache.

The bootstrap resolves the ref to a commit and runs an isolated temporary archive. It does not switch, reset, pull, or overwrite an existing checkout.

The production `mac.brennerspear.com` response must itself inject a pinned, 40-character commit SHA as `OPENCLAW_SETUP_REF` when it invokes the bootstrap. A redirect to a raw branch URL is insufficient: the downloaded branch script would otherwise retain its `main` default when fetching the repo. The endpoint wrapper should fetch `bootstrap-laptop.sh` from that same SHA and pass the identical SHA in `OPENCLAW_SETUP_REF`, following this shape:

```bash
#!/usr/bin/env bash
set -euo pipefail
PINNED_REF="<40-character-commit-sha>"
curl -fsSL "https://raw.githubusercontent.com/tychohq/openclaw-setup/${PINNED_REF}/macos/bootstrap-laptop.sh" \
  | OPENCLAW_SETUP_REF="$PINNED_REF" bash -s -- "$@"
```

Endpoint rollout and deployment are intentionally handled separately from this repository change.

## Mac Mini

The legacy always-on Mini remains at:

```bash
curl -fsSL mac-mini.brennerspear.com | bash
```

Its config remains [`config.sh`](config.sh) and its bootstrap remains [`bootstrap.sh`](bootstrap.sh). Choose the agent-stack guide:

- **[OpenClaw setup](../README.md)**
- **[Hermes setup](../README-hermes.md)**
