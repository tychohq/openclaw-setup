# Discord — OpenClaw Integration Notes

## Setup
- Create a Discord bot at https://discord.com/developers/applications
- Add bot to your server with appropriate permissions
- Configure in openclaw.json under `channels.discord`
- Set `groupPolicy: "allowlist"` to control which channels the bot responds in

## Key Settings
- `requireMention: false` — bot responds to all messages in allowed channels
- `dmPolicy: "pairing"` — DMs require device pairing
- `ackReactionScope: "all"` — bot reacts to acknowledge messages

## Platform Formatting
- No markdown tables (use bullet lists instead)
- Wrap links in `<>` to suppress embeds
- Max message length: 2000 chars (auto-splits longer messages)
- Use `filePath` for sending files (any readable path works)

## Channel-Level System Prompts
Each Discord channel/thread can have its own system prompt that gets injected into every message in that channel. Set this in the guild config under `channels`:

```json
"guilds": {
  "YOUR_GUILD_ID": {
    "requireMention": false,
    "channels": {
      "CHANNEL_ID": {
        "allow": true,
        "systemPrompt": "This channel is for project X. Focus on..."
      }
    }
  }
}
```

**Important:** Every channel needs `"allow": true` to be active — the bot won't respond in channels that aren't explicitly allowed (when using `groupPolicy: "allowlist"`). The `systemPrompt` is optional but powerful.

**Guild-level settings:**
- `requireMention: false` — bot responds to all messages in allowed channels (not just @mentions)

**Channel-level settings:**
- `allow: true` — required for the bot to respond in this channel
- `systemPrompt` — persistent context injected on every message (project details, rules, repos, persona, etc.)

Use system prompts to give the agent persistent context about what a channel is for — project details, rules, goals, relevant repos, specialized persona. The prompt appears as system context on every message in that channel without anyone needing to repeat it.

**Example channel types:**
- Project channels: point to repo path + AGENTS.md
- Research channels: set research workflow rules
- Therapy/coaching: set a specialized persona
- Activity feeds: describe the automated posting format
- Brain dumps: instruct how to process unstructured thoughts

## Channel Organization Tips
- Use categories to group channels by function
- Forum channels work well for project-specific discussions
- Thread channels keep conversations organized
- Pair each channel with a system prompt for best results
