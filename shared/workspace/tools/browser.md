# Browser Automation

## Two Browser Systems

OpenClaw has **two separate browser setups** — don't confuse them:

| | **agent-browser CLI** | **OpenClaw `browser` tool** |
|---|---|---|
| **Binary** | `agent-browser` (clawhub skill) | Built into OpenClaw |
| **Engine** | Real Chrome via CDP | Playwright's "Chrome for Testing" |
| **Profile** | `~/.agents/browser/profiles/default` | `~/.openclaw/browser/openclaw/user-data` |
| **CDP port** | 9222 | 18800 |
| **Google login** | ✅ Yes (real Chrome) | ❌ No (Chrome for Testing blocks it) |
| **Launch** | Script → `open -na "Google Chrome"` | Automatic (OpenClaw manages) |
| **Connect** | `agent-browser --cdp 9222 <command>` | `browser` tool with `profile="openclaw"` |
| **Use for** | Authenticated sites (Google, any logged-in sessions) | Unauthenticated scraping, headless tasks |

## agent-browser + Real Chrome (Primary)

**Architecture:** Launch real Chrome with remote debugging → agent-browser connects via `--cdp 9222`.

**Usage:**
```bash
agent-browser --cdp 9222 open "https://example.com"
agent-browser --cdp 9222 snapshot -i -c
agent-browser --cdp 9222 click @e2
agent-browser --cdp 9222 screenshot page.png
```

**Profile:** `~/.agents/browser/profiles/default` — the user's logged-in Chrome profile with cookies. Treat as sacred — never nuke it.

**Launch Chrome with CDP:**
```bash
open -na "Google Chrome" --args --user-data-dir="$HOME/.agents/browser/profiles/default" --remote-debugging-port=9222
```

## ⚠️ Profile Corruption Prevention Rules

1. **NEVER use `--profile` flag with agent-browser on your Chrome profile.** `--profile` launches Playwright's Chromium, which writes to the same profile dir in a different format. Two browsers writing = corruption.
2. **NEVER restore individual SQLite files** (Cookies, Login Data) into an existing profile. Either use the whole profile directory or start fresh.
3. **Chrome CANNOT be launched from `exec` tool** — always fails because exec subprocesses exit and kill Chrome's child processes. Only `open -na` (via script or manual) works.
4. **If Chrome won't start**, check for stale `SingletonLock` files: `rm -f ~/.agents/browser/profiles/default/Singleton*`
5. **If the profile is truly corrupted** (Chrome exits immediately), nuke the profile dir and re-login.

## `AGENT_BROWSER_PROFILE` env var — DO NOT SET

This env var makes agent-browser use Playwright's Chromium with a persistent profile. This conflicts with the real Chrome setup. Do not set it. Always use `--cdp 9222` instead.

## Google OAuth via agent-browser

Google's sign-in pages detect synthetic JS clicks and redirect to Help pages. **This includes `eval`-based clicks.**

**What works:** `agent-browser --cdp 9222 click @ref --timeout 15000` — Playwright's native click simulates real mouse input, which Google trusts.

**Key rules:**
- Always use `click @ref`, never `eval "element.click()"`
- Use `--timeout 15000` — OAuth pages are slow
- Use `snapshot -i` between each step to get fresh refs
- If stuck on account chooser, retry with `click @ref` — don't fall back to eval/keyboard

## Multi-Session Tab Conflicts

**Always open a new tab** (`agent-browser open <url> --new-tab`). Other agent sessions may be using existing tabs in the same Chrome instance. Never navigate in an existing tab — always start fresh.

## OpenClaw Browser (profile="openclaw") — For Unauthenticated Tasks

- Uses Playwright's "Chrome for Testing" — **cannot do Google sign-in**
- Profile: `~/.openclaw/browser/openclaw/user-data` (CDP port 18800)
- **Always pass `profile="openclaw"` on every browser tool call** — not just `open`. Actions like `snapshot`, `screenshot`, `act` will silently fall back to the Chrome extension relay if `profile` is omitted.
- **Headless by default** (`browser.headless: true`). If CAPTCHA or re-auth needed, set `browser.headless: false` via config.patch.
- **Snapshot refs go stale** after page navigation, timeouts, or any DOM change. Always re-snapshot immediately before clicking.
