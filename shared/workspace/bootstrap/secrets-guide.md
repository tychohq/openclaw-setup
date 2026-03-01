# API Keys & Secrets Guide

Where to get each key needed for a fully-functional OpenClaw setup.

## Required

| Key | Where to get it | Used for |
|-----|----------------|----------|
| **Anthropic API key** | https://console.anthropic.com/settings/keys | Primary AI model (Claude) |
| **Gemini API key** | https://aistudio.google.com/apikey | Memory search embeddings |

## Recommended

| Key | Where to get it | Used for |
|-----|----------------|----------|
| **Brave Search API key** | https://brave.com/search/api/ (free tier: 2000/mo) | Web search tool |
| **OpenAI API key** | https://platform.openai.com/api-keys | Whisper transcription, image gen, Codex |
| **OpenRouter API key** | https://openrouter.ai/keys | Access to other models (Qwen, Kimi, etc.) |

## Channel tokens

| Token | Where to get it | Used for |
|-------|----------------|----------|
| **Discord bot token** | https://discord.com/developers/applications → Bot → Reset Token | Discord channel |
| **Telegram bot token** | Talk to @BotFather on Telegram → /newbot | Telegram channel |
| **Slack bot/app tokens** | https://api.slack.com/apps → OAuth & Permissions | Slack channel |

## Where to put them

### Auth profiles (`~/.openclaw/agents/main/agent/auth-profiles.json`)
API keys for AI providers go here as profiles:
```json
{
  "version": 1,
  "profiles": {
    "anthropic:default": {
      "type": "api_key",
      "provider": "anthropic",
      "key": "sk-ant-..."
    }
  }
}
```

### Environment file (`~/.openclaw/.env`)
Service keys and channel tokens:
```
ANTHROPIC_API_KEY=sk-ant-...
GEMINI_API_KEY=AIza...
BRAVE_API_KEY=BSA...
OPENAI_API_KEY=sk-proj-...
DISCORD_TOKEN=MTQ3...
```

### Config file (`~/.openclaw/openclaw.json`)
Channel configuration (Discord guilds, Telegram groups, etc.)
See `~/projects/mac-mini-setup/config/` for templates.

## After adding keys
Restart the gateway: `openclaw gateway restart`
Verify: `cd ~/projects/mac-mini-setup && scripts/setup-openclaw.sh --check`
