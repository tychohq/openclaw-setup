# Step Type Reference

Detailed specification for each patch step type supported by `openclaw-patch`.

---

## 1. `file` — Write a file

Write content to any path on the instance. Supports inline content (short strings) or external file references (anything multi-line).

```yaml
- type: file
  path: ~/.openclaw/workspace/AGENTS.md
  content_file: workspace/AGENTS.md  # relative to files/
```

```yaml
- type: file
  path: ~/.openclaw/workspace/config/example.txt
  content: "single line content"
```

**Fields:**

| Field | Required | Description |
|-------|----------|-------------|
| `path` | yes | Destination path. `~` expands to `$HOME`. |
| `content_file` | one of | Path relative to `files/` directory. |
| `content` | one of | Inline string content. |

**Rules:**
- Exactly one of `content_file` or `content` is required.
- Parent directories are created automatically.
- Overwrites existing files (no merge). For config merging, use `config_patch`.

---

## 2. `config_patch` — Deep-merge into openclaw.json

Applies a JSON deep-merge to `~/.openclaw/openclaw.json` using `jq`'s `*` operator.

```yaml
- type: config_patch
  merge_file: configs/update-models.json  # relative to files/
```

**Fields:**

| Field | Required | Description |
|-------|----------|-------------|
| `merge_file` | yes | Path to JSON file relative to `files/`. |

**Rules:**
- Deep merge: nested objects merge recursively, scalars overwrite, arrays replace.
- Requires `jq` on the instance.
- If `openclaw.json` doesn't exist yet, creates it from the merge content (init-from-zero).
- Never include secrets (API keys, tokens). Those stay in `.env`.

---

## 3. `skill` — Install a custom skill

Copies a skill directory from the repo into `~/.openclaw/skills/`.

```yaml
- type: skill
  name: my-custom-skill
  source_dir: my-custom-skill-v2  # optional, defaults to name
```

**Fields:**

| Field | Required | Description |
|-------|----------|-------------|
| `name` | yes | Skill name (becomes destination directory name). |
| `source_dir` | no | Source directory name in `skills/` if different from `name`. |

**Rules:**
- Source directory must exist in `skills/` in the repo.
- Destination is `~/.openclaw/skills/<name>/`.
- Full copy — replaces existing skill entirely.

---

## 4. `clawhub` — Install/update ClawHub skills

Installs or updates skills from the public ClawHub registry.

```yaml
- type: clawhub
  skills:
    - "weather@latest"
    - "github@2.1.0"
```

**Fields:**

| Field | Required | Description |
|-------|----------|-------------|
| `skills` | yes | List of `name@version` strings. |

**Rules:**
- Requires `clawhub` CLI on the instance.
- Failures on individual skills are warnings (non-fatal).

---

## 5. `cron` — Register a cron job

Creates or updates a cron job definition file.

```yaml
- type: cron
  name: daily-healthcheck
  job_file: cron/daily-healthcheck.json  # relative to files/
```

**Fields:**

| Field | Required | Description |
|-------|----------|-------------|
| `name` | yes | Cron job identifier. |
| `job_file` | yes | Path to JSON job definition relative to `files/`. |

**Rules:**
- Writes the job JSON to `~/.openclaw/workspace/cron-jobs/<name>.json`.
- Job must be separately registered via `openclaw cron add` or the gateway API.

---

## 6. `exec` — Run a shell command

Escape hatch for anything the other step types can't handle.

```yaml
- type: exec
  command: "bun install -g openclaw-helper@latest"
```

**Fields:**

| Field | Required | Description |
|-------|----------|-------------|
| `command` | yes | Shell command to run via `eval`. |

**Rules:**
- Commands should be idempotent (safe to re-run).
- No interactive commands (stdin is not available).
- Failures are fatal (stop the patch).

---

## 7. `openclaw_update` — Update OpenClaw itself

Updates the OpenClaw package. Auto-detects `bun` vs `npm`.

```yaml
- type: openclaw_update
  version: latest  # or "1.2.3"
```

**Fields:**

| Field | Required | Description |
|-------|----------|-------------|
| `version` | no | Target version. Defaults to `latest`. |

**Rules:**
- Detects package manager: if `openclaw` binary resolves to a bun path, uses `bun`; otherwise `npm`.
- Should typically be followed by a `restart` step.

---

## 8. `restart` — Restart the OpenClaw gateway

```yaml
- type: restart
```

**Rules:**
- Tries `systemctl --user restart openclaw-gateway` first (Linux/systemd).
- Falls back to `openclaw gateway restart`.
- Non-fatal if restart fails (warns but doesn't stop the patch).
