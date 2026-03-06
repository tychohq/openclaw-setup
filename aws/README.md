# OpenClaw on AWS

One command to deploy OpenClaw on AWS. The setup wizard collects everything inline — from API keys to channel tokens — and generates the Terraform config. No manual SSH or `openclaw onboard` needed.

For advanced users, see [Advanced Deployment](#advanced-deployment) below.

## Cost (On-Demand, eu-central-1)

The setup wizard currently estimates the default deployment at **~$17/month** in `eu-central-1`.

Treat that as a rough starting point, not a bill guarantee. Actual cost varies with region, instance type, EBS volume size, data transfer, snapshots, and other AWS usage.

If you change `instance_type` or `ebs_volume_size` in [terraform/variables.tf](terraform/variables.tf), expect the monthly total to change as well.

## Quick Start (First Time)

```bash
git clone https://github.com/tychohq/openclaw-setup.git
cd openclaw-setup/aws
./setup.sh
```

The wizard walks you through:

1. **Checks prerequisites** — Terraform, AWS CLI, jq
2. **Verifies AWS access** — Current account, profile, or assume-role
3. **Selects region** — Frankfurt, N. Virginia, or Oregon
4. **Names your deployment** — Used for all AWS resource tags (e.g. `my-openclaw`)
5. **Configures OpenClaw** — Quick setup (enter API key + channel token inline), point to config files, or skip
6. **Scans for existing resources** — Checks for conflicts using your deployment name
7. **Deploys infrastructure** — VPC, subnet, IGW, SG, IAM, EC2
8. **Waits for instance readiness** — Confirms EC2 is ready and OpenClaw is installed

If you choose **Quick Setup** in step 5, the wizard generates `openclaw.json` and `.env` inline from your answers. The instance boots fully configured — no SSM-in-and-onboard step needed.

## Prerequisites

```bash
# Install Terraform (https://terraform.io/downloads)
# Install AWS CLI (https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
# Install jq (https://jqlang.github.io/jq/download/)
# Install SSM Session Manager plugin if missing (https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)
# Configure AWS credentials
aws configure
```

## What You Need

- **AWS account** with permissions to create VPC, EC2, IAM, S3, and DynamoDB resources
- **For the current AWS wizard (`./setup.sh`), at least one supported AI provider API key:**
  - Anthropic (`ANTHROPIC_API_KEY`) — [console.anthropic.com](https://console.anthropic.com/)
  - OpenAI (`OPENAI_API_KEY`) — [platform.openai.com](https://platform.openai.com/)
- **Other provider keys you may still want after deploy:**
  - OpenRouter (`OPENROUTER_API_KEY`) — [openrouter.ai](https://openrouter.ai/)
  - Gemini (`GEMINI_API_KEY`) — [aistudio.google.com](https://aistudio.google.com/)
- **At least one chat channel token:**
  - Discord (`DISCORD_TOKEN`) — [Discord Developer Portal](https://discord.com/developers/applications) → Bot → Token. Also need your user ID and guild ID.
  - Telegram (`TELEGRAM_BOT_TOKEN`) — [@BotFather](https://t.me/BotFather) → /newbot
  - Slack (`SLACK_BOT_TOKEN` + `SLACK_APP_TOKEN`) — see [Slack setup docs](https://docs.openclaw.ai/channels/slack)

`./setup.sh --auto` only accepts Anthropic or OpenAI as satisfying the provider requirement, and the interactive wizard currently only prompts for those same two providers. OpenRouter and Gemini can still be added after deploy via your OpenClaw config/auth files, but they are not part of the current wizard validation flow.

## Non-Interactive Deploy (`--auto`)

If you fill out all required variables in `.env`, you can skip every prompt:

```bash
cp .env.example .env
# Fill in all values (API key, bot token, guild ID, owner ID, etc.)
vim .env

./setup.sh --auto
```

Auto mode validates that all required fields are present before doing anything. If something's missing, it tells you exactly what and exits — no partial deploys. For AI providers, `--auto` currently validates only `ANTHROPIC_API_KEY` and `OPENAI_API_KEY`.

Great for CI, scripting, or re-deploys where your `.env` is already populated.

## Tear Down & Rebuild

```bash
# Destroy everything
./setup.sh --destroy

# Re-deploy from scratch
./setup.sh

# Or non-interactively
./setup.sh --auto
```

## Terraform State (S3 Backend)

By default, `setup.sh` stores Terraform state in S3 with DynamoDB locking. This means:

- **State is safe** — not lost if you delete the repo or switch machines
- **Locking** — prevents concurrent `terraform apply` from corrupting state
- **Versioned** — S3 versioning enabled for rollback if state gets corrupted

### How It Works

The setup wizard automatically:

1. Creates an S3 bucket: `{owner-name}-{assistant-name}-tfstate` (e.g. `brenner-spear-axel-tfstate`)
2. Creates a DynamoDB table: `{owner-name}-{assistant-name}-tfstate-lock`
3. Generates `backend.tf` (gitignored) with the S3 backend config
4. Migrates any existing local state to S3

### Cost

Effectively free — a few KB of S3 storage + occasional DynamoDB reads for locking.

### Opt Out

To use local state instead (not recommended):

```bash
# In your .env
TFSTATE_S3="false"
```

### Existing Deployments

If you have an existing deployment with local state, just re-run `setup.sh`. It will detect the local `terraform.tfstate` and migrate it to S3 automatically.

---

## Advanced Deployment

The current EC2 deployment path is driven by `./setup.sh`, not the older Terraform-only flow with `openclaw-secrets.json`, `workspace_files`, `custom_skills`, and `cron_jobs` variables documented in earlier versions of this README.

### Current Flow

Use a deployment directory and point the setup wizard at it:

```bash
./setup.sh --config ~/openclaw-deployments/my-agent
./setup.sh --config ~/openclaw-deployments/my-agent --auto
```

The deployment directory can contain:

- `.env` — wizard defaults and the required source for `--auto`
- `config-bundle.json` — extra OpenClaw config to apply after clone/setup
- `cron-selections.json` — cron job selections to enable at boot
- `skills-list.json` — ClawHub skills to preinstall

`setup.sh` base64-encodes those bundle files into environment variables (`CONFIG_BUNDLE_B64`, `CRON_SELECTIONS_B64`, `CLAWHUB_SKILLS`) and the slim cloud-init flow applies them on the EC2 instance.

### Real Repo Examples

If you want concrete examples from this repo, use files that actually exist today:

- Skills: `shared/skills/clawdstrike/SKILL.md`, `shared/skills/doc-layers/SKILL.md`
- Cron jobs: `shared/cron-jobs/self-reflection.json`, `shared/cron-jobs/error-log-digest.json`

### Updating a Deployment

For durable changes, update the files in your deployment directory and re-run `./setup.sh` (or `./setup.sh --config <dir> --auto`).

For one-off edits, connect over SSM and update the live files directly:

```bash
aws ssm start-session --target <instance-id> --region <region>

# Edit config:
sudo -u ec2-user vi /home/ec2-user/.openclaw/openclaw.json

# Update .env (API keys):
sudo -u ec2-user vi /home/ec2-user/.openclaw/.env
sudo -u ec2-user systemctl --user restart openclaw-gateway
```

The current deploy runs as `ec2-user`, with OpenClaw files under `/home/ec2-user/.openclaw/`. 

---

## Security

**Secrets in Terraform state**: All config variables are marked `sensitive = true`, which prevents them from appearing in plan/apply output. However, Terraform state files contain all variable values. Ensure your state backend is encrypted (S3 with SSE, Terraform Cloud, etc.).

**Wizard secrets handling**: The setup wizard writes secrets only to `/tmp/` temp files and passes them via `-var` flags. Temp files are cleaned up after apply. No secrets are written to the repo directory.

**Recommended approach**: Keep your deployment inputs in the directory you pass to `./setup.sh --config` — typically `.env`, plus optional `config-bundle.json`, `cron-selections.json`, and `skills-list.json` — and let the setup wizard encode them for cloud-init.

Keep any secret-bearing files out of git.

---

## Commands

```bash
# Connect to the instance (SSM shell)
aws ssm start-session --target <instance-id> --region <region>

# Run onboarding as the instance user (if not pre-configured)
sudo -u ec2-user openclaw onboard --install-daemon

# View install log
tail -f /var/log/openclaw-install.log

# View gateway logs (user service)
sudo -u ec2-user journalctl --user -u openclaw-gateway -f

# Restart gateway (user service)
sudo -u ec2-user systemctl --user restart openclaw-gateway

# Access dashboard locally via SSM port-forwarding (run from your machine)
aws ssm start-session \
	--target <instance-id> \
	--region <region> \
	--document-name AWS-StartPortForwardingSession \
	--parameters '{"portNumber":["18789"],"localPortNumber":["18789"]}'

# Then open
# http://localhost:18789/
# If you see "gateway token mismatch", fetch the token with:
# sudo -u ec2-user openclaw config get gateway.auth.token

# Destroy everything
./setup.sh --destroy
```

## License

MIT
