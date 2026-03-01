# Discord Bot Setup

## Step 1: Create the bot
1. Go to https://discord.com/developers/applications
2. Click **New Application** → name it (e.g. "OpenClaw")
3. Go to **Bot** → click **Reset Token** → copy the token
4. Under **Privileged Gateway Intents**, enable:
   - **Message Content Intent** ← critical, won't work without this
   - **Server Members Intent** (optional, for member info)

## Step 2: Invite to your server
Replace YOUR_APP_ID with the Application ID from the General Information page:
```
https://discord.com/api/oauth2/authorize?client_id=YOUR_APP_ID&permissions=412317273088&scope=bot
```

## Step 3: Get your IDs
Enable Developer Mode: User Settings → Advanced → Developer Mode

- **Your user ID**: Right-click your username → Copy User ID
- **Server (guild) ID**: Right-click server name → Copy Server ID

## Step 4: Configure OpenClaw
In `~/.openclaw/openclaw.json`, set:
```json
{
  "channels": {
    "discord": {
      "enabled": true,
      "token": "paste-bot-token-here",
      "groupPolicy": "allowlist",
      "dmPolicy": "pairing",
      "requireMention": false,
      "allowFrom": ["your-user-id"],
      "guilds": {
        "your-guild-id": {
          "requireMention": false
        }
      }
    }
  }
}
```

No need to list individual channels — all channels in the guild are enabled.
Add per-channel `systemPrompt` only if you want specialized behavior.

## Step 5: Enable the plugin
Make sure `plugins.allow` includes `"discord"` and `plugins.entries.discord.enabled` is `true`.

## Step 6: Restart
```
openclaw gateway restart
```

## Troubleshooting
- **Bot online but not responding**: Check `requireMention: false` at guild level
- **Bot not online**: Check token is correct, Message Content Intent is enabled
- **"Not allowed"**: Check `allowFrom` has your user ID, guild ID is in `guilds`
