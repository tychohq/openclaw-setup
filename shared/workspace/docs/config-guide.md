# OpenClaw Configuration Guide

Your `openclaw.json` is the brain of your setup. It controls which models you use, how memory works, what channels are connected, and how your agent behaves. This guide walks through every section you need to configure, explains **why** each setting matters, and ends with a complete example you can copy and customize.

The config lives at `~/.openclaw/openclaw.json` and uses JSON5 syntax (comments and trailing commas allowed).

> **New to OpenClaw?** Run `openclaw onboard` first — the wizard handles auth and basic config. Then come back here to fine-tune everything.

---

## Table of Contents

1. [Gateway Settings](#1-gateway-settings)
2. [Environment Variables & API Keys](#2-environment-variables--api-keys)
3. [Models & Auth](#3-models--auth)
4. [Agent Defaults](#4-agent-defaults)
5. [Memory & Search](#5-memory--search)
6. [Session Management](#6-session-management)
7. [Hooks](#7-hooks)
8. [Telegram Channel](#8-telegram-channel)
9. [Tools](#9-tools)
10. [Skills](#10-skills)
11. [Plugins](#11-plugins)
12. [Discovery & Network](#12-discovery--network)
13. [Complete Example Config](#13-complete-example-config)
14. [Gotchas & Troubleshooting](#14-gotchas--troubleshooting)

---

## 1. Gateway Settings

The Gateway is the long-running process that handles all incoming/outgoing messages, model calls, and tool execution.

```json5
{
  "gateway": {
    "port": 18789,
    "mode": "local",
    "bind": "loopback",
    "auth": {
      "mode": "token",
      "token": "<YOUR_GATEWAY_TOKEN>"
    }
  }
}
```

| Field | What It Does | Recommended |
|-------|-------------|-------------|
| `port` | Port the Gateway listens on | `18789` (default) |
| `mode` | `"local"` runs everything on your machine | `"local"` for personal use |
| `bind` | `"loopback"` = localhost only, `"all"` = network-accessible | `"loopback"` unless you need remote access |
| `auth.mode` | `"token"` requires a bearer token for API calls | Always use `"token"` |
| `auth.token` | The actual token string | Generate a random one: `openssl rand -hex 24` |

**Why `loopback`?** If your Gateway is only for your own machine, binding to localhost prevents any network exposure. If you need to access it from other devices (e.g., via Tailscale), set `bind: "all"` and make sure `auth.token` is strong.

---

## 2. Environment Variables & API Keys

API keys can be set in `env.vars` inside your config. They're only applied if not already set in your shell environment.

```json5
{
  "env": {
    "vars": {
      "ANTHROPIC_API_KEY": "<YOUR_ANTHROPIC_API_KEY>",
      "OPENAI_API_KEY": "<YOUR_OPENAI_API_KEY>",
      "OPENROUTER_API_KEY": "<YOUR_OPENROUTER_API_KEY>",
      "GEMINI_API_KEY": "<YOUR_GEMINI_API_KEY>",
      "PARALLEL_API_KEY": "<YOUR_PARALLEL_API_KEY>"
    }
  }
}
```

| Key | What It's For | Required? |
|-----|--------------|-----------|
| `ANTHROPIC_API_KEY` | Claude models (Opus, Sonnet) via Anthropic direct | Yes, unless using setup-token auth |
| `OPENAI_API_KEY` | OpenAI models, Whisper STT fallback | Optional — only if you use OpenAI models |
| `OPENROUTER_API_KEY` | Access third-party models (Qwen, Kimi, etc.) via unified API | Optional — only if you want non-Anthropic/OpenAI models |
| `GEMINI_API_KEY` | Free embedding provider for memory search | Recommended — free tier works for most setups |
| `PARALLEL_API_KEY` | Parallel AI deep research tool | Optional — for automated research workflows |

**Why `env.vars` instead of shell exports?** Keeps everything in one place. The config won't override keys already set in your shell, so you can use either approach. For secrets you don't want in a JSON file, use `~/.openclaw/.env` instead.

See `api-keys-checklist.md` for a complete list with sign-up links.

---

## 3. Models & Auth

### Auth Profiles

Auth profiles define how OpenClaw authenticates with each model provider.

```json5
{
  "auth": {
    "profiles": {
      "anthropic:default": {
        "provider": "anthropic",
        "mode": "api_key"
      },
      "anthropic:my-max-plan": {
        "provider": "anthropic",
        "mode": "token"
      },
      "openrouter:default": {
        "provider": "openrouter",
        "mode": "api_key"
      }
    },
    "order": {
      "anthropic": [
        "anthropic:my-max-plan",
        "anthropic:default"
      ]
    }
  }
}
```

**Two auth modes for Anthropic:**

- **`api_key`** — Standard API key authentication. You pay per token. Get a key from [console.anthropic.com](https://console.anthropic.com).
- **`token`** — Uses a Claude Max Plan setup-token. Models are included in your subscription — no per-token cost. Generate with `claude setup-token` from the Claude Code CLI, then paste into OpenClaw with `openclaw models auth paste-token --provider anthropic`.

**Why `auth.order`?** When you have multiple profiles for the same provider (e.g., Max Plan + API key), `order` controls which one is tried first. Put your subscription/included profile first, API key as fallback. If the first profile hits a rate limit, OpenClaw automatically tries the next one.

### Model Providers

Built-in providers (Anthropic, OpenAI, OpenRouter) work with just auth + a model name. For custom or third-party providers, define them in `models.providers`:

```json5
{
  "models": {
    "mode": "merge",
    "providers": {
      "openrouter": {
        "baseUrl": "https://openrouter.ai/api/v1",
        "apiKey": "OPENROUTER_API_KEY",
        "api": "openai-completions",
        "models": [
          {
            "id": "moonshotai/kimi-k2.5",
            "name": "Kimi K2.5",
            "reasoning": false,
            "input": ["text", "image"],
            "cost": { "input": 0.45, "output": 2.25 },
            "contextWindow": 262144,
            "maxTokens": 16384
          },
          {
            "id": "qwen/qwen3-coder",
            "name": "Qwen3 Coder",
            "reasoning": false,
            "input": ["text"],
            "cost": { "input": 0.22, "output": 1 },
            "contextWindow": 262144,
            "maxTokens": 16384
          },
          {
            "id": "qwen/qwen3-coder:free",
            "name": "Qwen3 Coder (free)",
            "reasoning": false,
            "input": ["text"],
            "cost": { "input": 0, "output": 0 },
            "contextWindow": 262000,
            "maxTokens": 16384
          }
        ]
      }
    }
  }
}
```

**Key fields for each model:**

| Field | What It Means |
|-------|--------------|
| `id` | Model identifier used by the provider's API |
| `name` | Human-readable display name |
| `reasoning` | Whether the model supports chain-of-thought reasoning tokens |
| `input` | Supported input types: `"text"`, `"image"` |
| `cost` | Per-million-token pricing (helps OpenClaw track spend) |
| `contextWindow` | Max tokens the model can process at once |
| `maxTokens` | Max output tokens per response |

**Why `mode: "merge"`?** This tells OpenClaw to merge your custom providers with the built-in catalog instead of replacing it. Without `"merge"`, you'd lose access to all built-in models.

### Default Model & Fallbacks

```json5
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "anthropic/claude-opus-4-6",
        "fallbacks": [
          "openrouter/moonshotai/kimi-k2.5",
          "openrouter/qwen/qwen3-coder:free"
        ]
      }
    }
  }
}
```

**How fallbacks work:** If your primary model is rate-limited or unavailable, OpenClaw automatically tries the next model in the fallback list. Put your strongest model first, then progressively cheaper/free alternatives.

### Model Allowlist & Aliases

```json5
{
  "agents": {
    "defaults": {
      "models": {
        "anthropic/claude-opus-4-6": { "alias": "opus" },
        "anthropic/claude-sonnet-4-20250514": {},
        "openrouter/moonshotai/kimi-k2.5": {},
        "openrouter/qwen/qwen3-coder": {},
        "openrouter/qwen/qwen3-coder:free": {}
      }
    }
  }
}
```

**Why define `models`?** This becomes the **allowlist** — only models listed here can be used. Aliases let you reference models by short names (e.g., `opus` instead of `anthropic/claude-opus-4-6`) in commands and cron jobs.

**Model selection strategy:** If your plan includes a top-tier model (e.g., Claude Opus on a Max Plan), use it as your default for everything including sub-agents. There's no cost reason to downgrade. Save cheaper models for automated cron jobs and trivial tasks.

---

## 4. Agent Defaults

```json5
{
  "agents": {
    "defaults": {
      "workspace": "~/.openclaw/workspace",
      "maxConcurrent": 6,
      "subagents": {
        "maxConcurrent": 8
      }
    }
  }
}
```

| Field | What It Does | Recommended |
|-------|-------------|-------------|
| `workspace` | Where your agent's files live | `"~/.openclaw/workspace"` |
| `maxConcurrent` | Max parallel model calls for the main agent | `4-8` depending on your rate limits |
| `subagents.maxConcurrent` | Max parallel sub-agents that can run simultaneously | `6-10` — higher if you delegate a lot |

**Why limit concurrency?** Too many parallel calls can hit provider rate limits, causing cascading failures. Start conservative and increase as you learn your limits.

---

## 5. Memory & Search

This is one of OpenClaw's most powerful features. It vector-indexes your Markdown files so the agent can semantically search across everything you've written.

### Memory Backend (QMD)

```json5
{
  "memory": {
    "backend": "builtin",
    "qmd": {
      "includeDefaultMemory": true,
      "paths": [
        {
          "path": ".",
          "name": "workspace",
          "pattern": "**/*.md"
        }
      ],
      "update": {
        "interval": "5m"
      }
    }
  }
}
```

| Field | What It Does |
|-------|-------------|
| `backend` | `"builtin"` uses the built-in SQLite indexer. `"qmd"` uses the QMD sidecar (BM25 + vectors + reranking — more powerful but requires separate install) |
| `qmd.includeDefaultMemory` | Auto-indexes `MEMORY.md` + `memory/**/*.md` |
| `qmd.paths` | Additional paths to index. The example indexes ALL `.md` files in the workspace |
| `qmd.update.interval` | How often to re-scan for changes (`"5m"` = every 5 minutes) |

**Why index everything?** When you add `{ path: ".", pattern: "**/*.md" }`, every Markdown file in your workspace becomes semantically searchable. Your agent can find relevant context from research, docs, daily notes — everything. This is the foundation of a truly knowledgeable agent.

### Memory Search Configuration

```json5
{
  "agents": {
    "defaults": {
      "memorySearch": {
        "sources": ["memory", "sessions"],
        "extraPaths": ["."],
        "provider": "gemini",
        "experimental": {
          "sessionMemory": true
        },
        "fallback": "none"
      }
    }
  }
}
```

| Field | What It Does |
|-------|-------------|
| `sources` | What gets searched: `"memory"` = Markdown files, `"sessions"` = past conversations |
| `extraPaths` | Additional directories to index (`.` = entire workspace) |
| `provider` | Embedding provider: `"gemini"` (free tier), `"openai"`, or `"local"` |
| `experimental.sessionMemory` | Index past session transcripts for search (powerful but experimental) |
| `fallback` | What to use if primary provider fails: `"openai"`, `"gemini"`, `"local"`, or `"none"` |

**Embedding provider choice:**

| Provider | Cost | Speed | Quality | Notes |
|----------|------|-------|---------|-------|
| `gemini` | Free (with quota) | Fast | Good | Best for starting out. Uses `gemini-embedding-001`. Has daily/hourly quota limits — if hit, indexing pauses until quota resets. |
| `openai` | ~$0.02/1M tokens | Fast | Excellent | More reliable for large workspaces. Uses `text-embedding-3-small`. Supports batch indexing (cheaper for backfills). |
| `local` | Free | Slower | Decent | Runs on your machine via `node-llama-cpp`. No API calls needed. Requires `pnpm approve-builds`. |

**How it works under the hood:**

1. OpenClaw chunks your Markdown files (~400 tokens per chunk with 80-token overlap)
2. Each chunk is embedded (converted to a vector) using your chosen provider
3. Vectors are stored in a per-agent SQLite database at `~/.openclaw/memory/<agentId>.sqlite`
4. When the agent calls `memory_search`, it embeds the query and finds the most similar chunks
5. Hybrid search (BM25 + vector) combines keyword and semantic matching for best results

---

## 6. Session Management

### Daily Reset

```json5
{
  "session": {
    "reset": {
      "mode": "daily",
      "atHour": 4
    }
  }
}
```

**Why daily reset?** Without resets, sessions grow indefinitely. Eventually, the context window fills up and compaction kicks in aggressively, losing nuance. A daily reset at 4 AM gives you a fresh context each morning while maintaining continuity through your memory files.

You can also configure idle-based resets:

```json5
{
  "session": {
    "reset": {
      "mode": "daily",
      "atHour": 4,
      "idleMinutes": 480
    }
  }
}
```

This creates a new session after 8 hours of inactivity OR at 4 AM — whichever comes first.

### Compaction

```json5
{
  "agents": {
    "defaults": {
      "compaction": {
        "mode": "safeguard"
      }
    }
  }
}
```

**What is compaction?** When a session approaches its context window limit, OpenClaw summarizes older messages into a compact summary and keeps only recent messages. This lets conversations continue indefinitely without losing the thread.

**Why `"safeguard"`?** The safeguard mode triggers a pre-compaction "memory flush" — before summarizing, the agent writes important context to disk (daily notes, MEMORY.md). This ensures critical information survives compaction. Without it, details from early in a long conversation could be lost.

**How the memory flush works:**
1. When the session is ~4,000 tokens from triggering compaction, OpenClaw sends a silent prompt to the agent
2. The agent writes any important context to `memory/YYYY-MM-DD.md`
3. The agent replies with `NO_REPLY` (invisible to you)
4. Compaction proceeds normally

---

## 7. Hooks

Hooks are event-driven scripts that run inside the Gateway when specific things happen — like starting a new session, resetting, or issuing `/new`. OpenClaw ships with bundled hooks you can enable.

### Session Memory Hook

The most important bundled hook. When you issue `/new` (or a daily reset fires), the `session-memory` hook saves a summary of the outgoing session's context into your memory files before the session is wiped. Without it, anything the agent learned during a session that wasn't explicitly written to disk is lost.

```json5
{
  "hooks": {
    "internal": {
      "enabled": true,
      "entries": {
        "session-memory": {
          "enabled": true
        }
      }
    }
  }
}
```

| Field | What It Does |
|-------|-------------|
| `hooks.internal.enabled` | Master switch for all internal hooks |
| `entries.session-memory.enabled` | Enable the session-memory hook specifically |

**How it connects to the memory pipeline:**

This hook is one piece of a three-part system for session recall:

1. **`hooks.internal.entries.session-memory`** — Saves session context to memory files on `/new` and resets
2. **`memorySearch.experimental.sessionMemory: true`** — Indexes session transcripts into the vector store (so they're searchable)
3. **`memorySearch.sources: ["sessions"]`** — Includes those indexed transcripts in `memory_search` results

You need all three for full session memory. The hook handles *capture*, `sessionMemory` handles *indexing*, and `sources` handles *retrieval*.

**Other bundled hooks:**

| Hook | Event | What It Does |
|------|-------|-------------|
| `session-memory` | `command:new` | Saves session context to memory on reset |
| `command-logger` | all commands | Logs commands to `~/.openclaw/logs/commands.log` |
| `bootstrap-extra-files` | `agent:bootstrap` | Injects additional files during workspace bootstrap |
| `boot-md` | `gateway:startup` | Runs `BOOT.md` when the gateway starts |

Enable hooks via CLI: `openclaw hooks enable <name>` or via config as shown above.

---

## 8. Telegram Channel

This is probably the most involved section. See `telegram-setup-guide.md` for the full setup walkthrough — this covers the config structure.

```json5
{
  "channels": {
    "telegram": {
      "enabled": true,
      "botToken": "<YOUR_BOT_TOKEN>",
      "dmPolicy": "pairing",
      "groupPolicy": "allowlist",
      "allowFrom": ["<YOUR_TELEGRAM_USER_ID>"],
      "groups": {
        "<YOUR_GROUP_ID>": {
          "requireMention": false,
          "enabled": true,
          "topics": {
            "<TOPIC_ID_MAIN>": {
              "systemPrompt": "This is the main conversation topic. Help with general questions, daily tasks, and quick requests."
            },
            "<TOPIC_ID_RESEARCH>": {
              "systemPrompt": "This topic is for research tasks. Help with deep dives, comparisons, gathering information, and synthesizing findings."
            },
            "<TOPIC_ID_ACTIVITY>": {
              "systemPrompt": "This topic is an automated activity feed. It logs workspace changes for transparency and auditability."
            },
            "<TOPIC_ID_DEV>": {
              "systemPrompt": "This topic is for development tasks — PR updates, code reviews, CI status, and deployment notifications."
            }
          }
        }
      }
    }
  }
}
```

| Field | What It Does |
|-------|-------------|
| `botToken` | Your Telegram bot token from @BotFather |
| `dmPolicy` | `"pairing"` = require approval code for new DM conversations. Safest option. |
| `groupPolicy` | `"allowlist"` = only respond in groups you've explicitly configured |
| `allowFrom` | Array of Telegram user IDs that can interact with the bot |
| `requireMention` | `false` = respond to every message in the group (good for your main group where you're the only user). `true` = only respond when @mentioned. |
| `topics` | Per-topic configuration with custom system prompts |

**Why per-topic system prompts?** Each topic gets its own conversation context and personality. Your Research topic can have instructions to use deep research tools. Your Dev topic can know about your codebase. Your Activity Feed topic can be purely automated. This isolation is one of OpenClaw's best features.

**Getting your Telegram user ID:** Send a message to your bot, then check:
```bash
curl "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates"
```
Look for `from.id` in the response.

**Getting group/topic IDs:** After adding the bot to your group:
```bash
curl "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates"
```
Look for `chat.id` (group) and `message_thread_id` (topic).

### Example Topic System Prompts

Here are some battle-tested system prompts for different topic types:

**Research topic:**
```
This topic is for research tasks. Help with deep dives, comparisons, gathering information, and synthesizing findings. Always save research outputs as files in the workspace.
```

**Brain dumps / voice notes:**
```
This topic is for brain dumps — unstructured thoughts, voice notes, ideas, and stream of consciousness. Help process, organize, and extract actionable items from raw thoughts.
```

**Project-specific topic:**
```
This is the <PROJECT_NAME> project topic. Repo: <REPO_PATH>. Stack: <TECH_STACK>. Track progress, bugs, features, and updates here.
```

**Activity feed (automated):**
```
This topic is an automated activity feed. It logs all changes made to workspace files. Each post includes the files changed, a summary, and verbatim diffs when short enough.
```

---

## 9. Tools

### Speech-to-Text (STT)

If you send voice messages via Telegram, configure STT to transcribe them:

```json5
{
  "tools": {
    "media": {
      "audio": {
        "enabled": true,
        "models": [
          {
            "type": "cli",
            "command": "/path/to/your/stt-binary",
            "args": ["transcribe", "{{MediaPath}}"],
            "timeoutSeconds": 60
          }
        ]
      }
    }
  }
}
```

**The `{{MediaPath}}` template:** OpenClaw downloads the voice message to a temp file and replaces `{{MediaPath}}` with its path before running your command. Your STT tool gets the actual audio file.

**STT options:**

| Tool | Type | Speed | Setup |
|------|------|-------|-------|
| [FluidAudio](https://github.com/FluidInference/FluidAudio) | CLI (local, macOS) | Very fast (Apple Neural Engine) | Build from source, runs CoreML Parakeet model |
| [whisper-cpp](https://github.com/ggerganov/whisper.cpp) | CLI (local) | Fast | `brew install whisper-cpp`, download models |
| OpenAI Whisper API | API | Medium | Needs `OPENAI_API_KEY`, costs per minute |

**For API-based STT** (no local binary needed):
```json5
{
  "tools": {
    "media": {
      "audio": {
        "enabled": true,
        "models": [
          {
            "type": "api",
            "provider": "openai",
            "model": "whisper-1"
          }
        ]
      }
    }
  }
}
```

---

## 10. Skills

Skills are capability modules. Some need their own API keys:

```json5
{
  "skills": {
    "entries": {
      "brave-search": {
        "apiKey": "<YOUR_BRAVE_SEARCH_API_KEY>"
      }
    }
  }
}
```

| Skill | Key Needed | Where to Get It |
|-------|-----------|-----------------|
| `brave-search` | Brave Search API key | [brave.com/search/api](https://brave.com/search/api/) — free tier available |
| `goplaces` | Google Places API key | [Google Cloud Console](https://console.cloud.google.com/) |

**Why Brave Search?** The `web_search` tool uses Brave's API. Without a key, your agent can still use `web_fetch` (scraping), but `web_search` (structured results with snippets) won't work. The free tier gives you 2,000 queries/month.

---

## 11. Plugins

Plugins extend OpenClaw's core functionality. Enable only what you need:

```json5
{
  "plugins": {
    "allow": [
      "telegram",
      "memory-core",
      "device-pair"
    ],
    "entries": {
      "telegram": {
        "enabled": true
      }
    }
  }
}
```

| Plugin | What It Does |
|--------|-------------|
| `telegram` | Telegram bot channel support |
| `memory-core` | Memory search tools (`memory_search`, `memory_get`) |
| `device-pair` | Pair mobile devices for camera, location, notifications |
| `whatsapp` | WhatsApp channel support |

**Why `plugins.allow`?** This is an explicit allowlist. Only plugins listed here will be loaded. This prevents unexpected plugins from activating and keeps your setup predictable.

---

## 12. Discovery & Network

```json5
{
  "discovery": {
    "wideArea": { "enabled": false },
    "mdns": { "mode": "minimal" }
  }
}
```

| Field | What It Does | Recommended |
|-------|-------------|-------------|
| `wideArea.enabled` | Whether to advertise on the wider network | `false` for personal use |
| `mdns.mode` | Local network discovery: `"minimal"`, `"full"`, or `"off"` | `"minimal"` — allows device pairing without broadcasting everything |

---

## 13. Complete Example Config

Copy this, fill in your values, and save as `~/.openclaw/openclaw.json`:

```json5
{
  // === GATEWAY ===
  "gateway": {
    "port": 18789,
    "mode": "local",
    "bind": "loopback",
    "auth": {
      "mode": "token",
      "token": "<GENERATE_WITH: openssl rand -hex 24>"
    }
  },

  // === API KEYS ===
  "env": {
    "vars": {
      "ANTHROPIC_API_KEY": "<YOUR_ANTHROPIC_API_KEY>",
      "OPENAI_API_KEY": "<YOUR_OPENAI_API_KEY>",
      "OPENROUTER_API_KEY": "<YOUR_OPENROUTER_API_KEY>",
      "GEMINI_API_KEY": "<YOUR_GEMINI_API_KEY>"
    }
  },

  // === AUTH PROFILES ===
  "auth": {
    "profiles": {
      "anthropic:default": {
        "provider": "anthropic",
        "mode": "api_key"
      },
      "openrouter:default": {
        "provider": "openrouter",
        "mode": "api_key"
      }
    },
    "order": {
      "anthropic": ["anthropic:default"]
    }
  },

  // === MODEL PROVIDERS ===
  // Built-in providers (anthropic, openai) don't need models.providers config.
  // Only define custom/third-party providers here.
  "models": {
    "mode": "merge",
    "providers": {
      "openrouter": {
        "baseUrl": "https://openrouter.ai/api/v1",
        "apiKey": "OPENROUTER_API_KEY",
        "api": "openai-completions",
        "models": [
          {
            "id": "moonshotai/kimi-k2.5",
            "name": "Kimi K2.5",
            "reasoning": false,
            "input": ["text", "image"],
            "cost": { "input": 0.45, "output": 2.25, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 262144,
            "maxTokens": 16384
          },
          {
            "id": "qwen/qwen3-coder",
            "name": "Qwen3 Coder",
            "reasoning": false,
            "input": ["text"],
            "cost": { "input": 0.22, "output": 1, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 262144,
            "maxTokens": 16384
          },
          {
            "id": "qwen/qwen3-coder:free",
            "name": "Qwen3 Coder (free)",
            "reasoning": false,
            "input": ["text"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 262000,
            "maxTokens": 16384
          }
        ]
      }
    }
  },

  // === AGENT DEFAULTS ===
  "agents": {
    "defaults": {
      "model": {
        "primary": "anthropic/claude-opus-4-6",
        "fallbacks": [
          "openrouter/moonshotai/kimi-k2.5",
          "openrouter/qwen/qwen3-coder:free"
        ]
      },
      "models": {
        "anthropic/claude-opus-4-6": { "alias": "opus" },
        "anthropic/claude-sonnet-4-20250514": {},
        "openrouter/moonshotai/kimi-k2.5": {},
        "openrouter/qwen/qwen3-coder": {},
        "openrouter/qwen/qwen3-coder:free": {}
      },
      "workspace": "~/.openclaw/workspace",
      "memorySearch": {
        "sources": ["memory", "sessions"],
        "extraPaths": ["."],
        "provider": "gemini",
        "experimental": { "sessionMemory": true },
        "fallback": "none"
      },
      "compaction": {
        "mode": "safeguard"
      },
      "maxConcurrent": 6,
      "subagents": {
        "maxConcurrent": 8
      }
    }
  },

  // === MEMORY & INDEXING ===
  "memory": {
    "backend": "builtin",
    "qmd": {
      "includeDefaultMemory": true,
      "paths": [
        {
          "path": ".",
          "name": "workspace",
          "pattern": "**/*.md"
        }
      ],
      "update": {
        "interval": "5m"
      }
    }
  },

  // === SESSION MANAGEMENT ===
  "session": {
    "reset": {
      "mode": "daily",
      "atHour": 4
    }
  },

  // === HOOKS ===
  "hooks": {
    "internal": {
      "enabled": true,
      "entries": {
        "session-memory": {
          "enabled": true
        }
      }
    }
  },

  // === TOOLS ===
  "tools": {
    "media": {
      "audio": {
        "enabled": true,
        "models": [
          {
            "type": "cli",
            "command": "/path/to/stt-binary",
            "args": ["transcribe", "{{MediaPath}}"],
            "timeoutSeconds": 60
          }
        ]
      }
    }
  },

  // === SKILLS ===
  "skills": {
    "entries": {
      "brave-search": {
        "apiKey": "<YOUR_BRAVE_SEARCH_API_KEY>"
      }
    }
  },

  // === TELEGRAM ===
  "channels": {
    "telegram": {
      "enabled": true,
      "botToken": "<YOUR_BOT_TOKEN>",
      "dmPolicy": "pairing",
      "groupPolicy": "allowlist",
      "allowFrom": ["<YOUR_TELEGRAM_USER_ID>"],
      "groups": {
        "<YOUR_GROUP_ID>": {
          "requireMention": false,
          "enabled": true,
          "topics": {
            "<TOPIC_ID_1>": {
              "systemPrompt": "Main conversation topic. Help with general questions and daily tasks."
            },
            "<TOPIC_ID_2>": {
              "systemPrompt": "Research topic. Help with deep dives, comparisons, and analysis."
            },
            "<TOPIC_ID_3>": {
              "systemPrompt": "Automated activity feed. Logs workspace file changes."
            }
          }
        }
      }
    }
  },

  // === PLUGINS ===
  "plugins": {
    "allow": ["telegram", "memory-core", "device-pair"],
    "entries": {
      "telegram": { "enabled": true }
    }
  },

  // === MESSAGES ===
  "messages": {
    "ackReactionScope": "group-mentions"
  },

  // === DISCOVERY ===
  "discovery": {
    "wideArea": { "enabled": false },
    "mdns": { "mode": "minimal" }
  }
}
```

---

## 14. Gotchas & Troubleshooting

### Gemini Embedding Quota Limits

The Gemini free tier has daily/hourly quota limits for embeddings. If you see `429 RESOURCE_EXHAUSTED` errors during indexing:

- **Don't panic** — this is normal. The quota resets after a few hours.
- Retries with exponential backoff won't help within the same quota window.
- For large workspaces, consider switching to OpenAI embeddings (more reliable, small cost).
- You can run `openclaw memory index --force` after the quota resets to catch up.

### Session Memory Can Go Read-Only

The SQLite memory database can occasionally go read-only, causing `[memory] sync failed: Error: attempt to write a readonly database` on every sync attempt. When this happens:

- No new content gets indexed until it's fixed.
- Check file permissions: `ls -la ~/.openclaw/agents/main/memory/`
- A gateway restart usually fixes it: `openclaw gateway restart`
- Possible causes: disk pressure, concurrent write locks, or database corruption.

### Config Validation Is Strict

OpenClaw rejects configs with unknown keys, typos, or invalid types. The Gateway won't start with a broken config.

- Run `openclaw doctor` to see exactly what's wrong.
- Run `openclaw doctor --fix` to auto-repair common issues.
- Comments are allowed (JSON5), but make sure your JSON structure is valid.

### Anthropic Token Auth Can Expire

If you're using `mode: "token"` (Claude Max Plan / setup-token):

- Tokens can expire or be revoked without warning.
- If you see 401 errors, re-run `claude setup-token` and paste the new token.
- Use `openclaw models auth paste-token --provider anthropic` to update.
- Having an API key as a fallback profile prevents complete outages.

### Don't Route Anthropic Through OpenRouter

If you have direct Anthropic access (API key or Max Plan), never route Anthropic models through OpenRouter. OpenRouter charges per-token for Anthropic models, and you'd be paying twice. Your `models.providers` should only list non-Anthropic models under the OpenRouter provider.

### `models` Becomes an Allowlist

Once you define `agents.defaults.models`, it becomes the complete list of allowed models. Any model not listed there won't be usable — even if the provider is configured. If you add a new model to a provider, remember to add it to the `models` allowlist too.

### Gateway Auth Token

Always set a gateway auth token, even when binding to loopback. Some tools and integrations make requests to the gateway API, and a token prevents accidental unauthorized access if your bind settings change later.

---

## Next Steps

1. **Run the wizard first:** `openclaw onboard` handles the basics
2. **Copy this template config** and fill in your values
3. **Start small:** Get Telegram working with one topic, then expand
4. **Check the logs:** `openclaw logs` shows what's happening under the hood
5. **Iterate:** Your config will evolve as you discover what works for your workflow

For API key sign-up links, see `api-keys-checklist.md`.