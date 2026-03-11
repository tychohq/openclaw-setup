# AWS Reference

## Authentication: Device Auth Flow

**Never ask the user to manually run `aws sso login` or paste credentials.** Use the device authorization flow — run the command yourself, extract the URL and code, and send them to the user.

### AWS SSO Login

**Critical: The `aws sso login` process must stay alive the ENTIRE time** — from generating the code, through the user approving in their browser, until the CLI saves the cached token. If the process dies before the token is saved, the approval is lost and the user has to do it again.

#### Step-by-step

1. **Start login as a background process** with enough `yieldMs` to capture the URL/code output:
   ```bash
   aws sso login --profile <profile> --no-browser --use-device-code 2>&1
   ```
   Use `exec` with `background: true` and `yieldMs: 5000` (5 seconds is enough to get the URL output).

2. **Immediately send the code to the user.** Don't compose a long message — just send the link. Prefer the pre-filled URL when the SSO portal supports it:
   ```
   https://<sso-portal>.awsapps.com/start/#/device/<CODE>
   ```
   Otherwise send the generic URL + code separately.

3. **Do NOT kill or abandon the background process.** It must keep polling until the user completes auth. When the user says "done", poll the process (`process` tool with `action: "poll"`) to confirm it exited successfully.

4. **Verify credentials are live:**
   ```bash
   aws sts get-caller-identity --profile <profile>
   ```

#### Common mistakes
- ❌ Running the login, extracting the code, then letting the process die (token never saved)
- ❌ Generating the code in one agent turn and sending it in the next (wasted time on the code expiry clock)
- ❌ Running `aws sso login` again after the user approved (the first process already saved the token — just verify with `sts get-caller-identity`)

Session tokens are cached — no need to re-auth until they expire (typically 8-12 hours).

### When to Re-authenticate

- `ExpiredTokenException` or `UnauthorizedSSOTokenException` errors → re-run the device auth flow
- Before any `terraform apply` or `aws` CLI operation, verify credentials are fresh:
  ```bash
  aws sts get-caller-identity --profile <profile> 2>/dev/null
  ```

## SSH via SSM (Session Manager)

For EC2 instances without public IPs, use SSM instead of direct SSH:

```bash
aws ssm start-session --target <instance-id> --region <region> --profile <profile>
```

**Requirements:**
- Active SSO session (see device auth above)
- SSM agent running on the target instance (standard AL2023 AMIs include it; minimal AMIs do NOT)
- Instance must have IAM role with `AmazonSSMManagedInstanceCore` policy
- The `session-manager-plugin` must be installed locally (`brew install session-manager-plugin`)

### SSH over SSM (ProxyCommand)

If you need full SSH features (scp, port forwarding), configure `~/.ssh/config`:

```
Host my-instance
    HostName <instance-id>
    User ec2-user
    ProxyCommand aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters 'portNumber=%p' --region <region> --profile <profile>
```

Then: `ssh my-instance`

## General Device Auth Pattern

This same pattern applies to ALL CLI tools that support device/browser auth. **Never ask the user to log in from a CLI prompt.** Instead:

1. Run the CLI command with `--no-browser` (or equivalent flag) **as a background process** (`exec` with `background: true`)
2. Parse out the authorization URL and code from initial output
3. **Immediately** send the URL + code to the user in chat — don't compose a long message first
4. **Keep the background process alive** — do NOT kill it. It must stay running until the user completes auth and the CLI saves the token.
5. When the user confirms, poll the process to verify success, then test credentials.

**Two things kill device auth flows:**
- **Timing:** Codes expire (AWS = 10 min, others vary). The clock starts when you run the command, not when the user sees the code.
- **Process lifecycle:** The CLI must stay alive to receive the callback and cache the token. If the process dies before that, the user's approval is wasted.

Common examples:
- **AWS SSO:** `aws sso login --no-browser --use-device-code`
- **Google (gog):** `gog auth add <email> --remote`
- **GitHub:** `gh auth login` (outputs a device code)
- **Codex:** `codex login --device-auth`

The user opens the link on any device (phone, laptop), completes auth, and the CLI picks it up automatically.
