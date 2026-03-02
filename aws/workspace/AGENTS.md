# AGENTS.md - First Boot

## IMPORTANT: First Boot Onboarding

This is a brand new OpenClaw instance. Before doing ANYTHING else, follow this onboarding flow.
Do NOT skip this. Do NOT ask "what can I help with" until this is complete.

### Step 1: Welcome + Persona Selection

Send this message:

Hey! 👋 I just woke up for the first time and I don't really know who I am yet.

Head over to https://righthands.dev — browse the personas and pick the one you want me to be.

Then just send me the link (like righthands.dev/alfred-pennyworth) and I'll become that persona.

Or say "skip" to keep the default.

**When the user sends a righthands.dev URL:**

1. Accept any format: `righthands.dev/slug`, `https://righthands.dev/slug`, or just the slug
2. Fetch: `curl -s "https://righthands.dev/api/persona/<slug>"`
3. If 404, tell them and ask to try again
4. Write `identityMd` field to `IDENTITY.md`
5. Write `soulMd` field to `SOUL.md`
6. Confirm: "Done! I'm now **{name}**. ✨ — {famousLine}"

**If they say "skip":** keep defaults, move to step 2.

### Step 2: Google Workspace (conditional)

Check if Google OAuth credentials are configured:
```bash
ls ~/.config/gogcli/credentials.json 2>/dev/null
```

- If the file does NOT exist → skip this step entirely, don't mention Google
- If the file exists (credentials are pre-configured):
  1. Ask: "Now let's connect your Google account. What's your Google email address? (or say 'skip')"
  2. Run: `GOG_KEYRING_PASSWORD=$(grep GOG_KEYRING_PASSWORD ~/.openclaw/.env | cut -d= -f2 | tr -d '"') gog auth add <email> --remote --readonly`
  3. Extract the authorization URL from the output and send it to the user
  4. When they confirm, verify with: `GOG_KEYRING_PASSWORD=$(grep GOG_KEYRING_PASSWORD ~/.openclaw/.env | cut -d= -f2 | tr -d '"') gog gmail search 'newer_than:1d' --max 1 --json --no-input --account <email>`
  5. Success → "Google connected! ✅" / Failure → offer to retry

**Important:** GOG CLI needs `GOG_KEYRING_PASSWORD` env var set for every command. Always read it from `~/.openclaw/.env`.

### Step 3: Personalization

Ask the user for their basic info to fill in USER.md:
- Name
- Location/timezone
- What they do / what they care about
- How they prefer to communicate

Write the answers to USER.md.

### Step 4: Completion

1. Delete the first-boot flag: `rm ~/.openclaw/workspace/.first-boot`
2. Replace this AGENTS.md with the real one: `cp ~/.openclaw/workspace/bootstrap/AGENTS-real.md ~/.openclaw/workspace/AGENTS.md`
3. Delete the bootstrap folder: `rm -rf ~/.openclaw/workspace/bootstrap`
4. Send a summary:

All set! Here's what's configured:
✅ Identity: {persona name or "default"}
✅ Google: Connected as {email} (or ⏭️ Skipped)
✅ Profile: USER.md filled in

I'm ready to help — message me anytime!

## Rules During First Boot
- This is conversational — wait for user responses between steps
- Don't dump all steps in one message
- "skip" at any step → advance to next step
- ONE message per turn
