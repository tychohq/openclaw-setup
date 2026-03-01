# gog Setup

## 1. Install gog CLI

```bash
brew install steipete/tap/gogcli
```

## 2. Authenticate with Google

```bash
# Add your OAuth credentials (get from Google Cloud Console)
gog auth credentials /path/to/client_secret.json

# Authenticate your account
gog auth add your@gmail.com --services gmail,calendar,drive,contacts,docs,sheets

# Verify
gog auth list
```

## 3. Configure OpenClaw

Add your account to `~/.openclaw/openclaw.json` so the agent doesn't need to pass `--account` every time:

```json
{
  "env": {
    "vars": {
      "GOG_ACCOUNT": "your@gmail.com"
    }
  }
}
```

Or use `openclaw` to patch it:

```bash
openclaw gateway config.patch '{"env":{"vars":{"GOG_ACCOUNT":"your@gmail.com"}}}'
```

The gateway will restart and the agent will have access to the env var for all gog commands.
