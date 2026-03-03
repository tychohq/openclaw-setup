# Step Type Reference

Detailed specification for each patch step type supported by `openclaw-patch`.

---

## 1. `file` — Write or append to a file

Write content to any path on the instance. Supports inline content or external file references, with overwrite or append modes.

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

Append mode with idempotent marker:

```yaml
- type: file
  path: ~/.openclaw/workspace/AGENTS.md
  content: "## Custom Section\nSome content here"
  mode: append
  marker: "## Custom Section"  # only append if marker not already present
```

**Fields:**

| Field | Required | Description |
|-------|----------|-------------|
| `path` | yes | Destination path. `~` expands to `$HOME`. |
| `content_file` | one of | Path relative to `files/` directory. |
| `content` | one of | Inline string content. |
| `mode` | no | `overwrite` (default) or `append`. |
| `marker` | no | String to check for idempotent appends. Only appends if marker is not already in the file. |

**Rules:**
- Exactly one of `content_file` or `content` is required.
- Parent directories are created automatically.
- `mode: overwrite` replaces the file. `mode: append` adds to end.
- `marker` only works with `mode: append`. If the marker string exists in the file, the append is skipped.

---

## 2. `config_set` — Set a single config field

Calls `openclaw config set <path> <value>` for individual config fields.

```yaml
- type: config_set
  path: models.default
  value: "anthropic/claude-sonnet-4-20250514"
```

For complex objects, value can be JSON:

```yaml
- type: config_set
  path: agent.memory
  value: '{"enabled": true, "maxFiles": 100}'
```

**Fields:**

| Field | Required | Description |
|-------|----------|-------------|
| `path` | yes | Dot-path config key (e.g. `models.default`). |
| `value` | yes | Value to set (string or JSON). |

**Rules:**
- Requires `openclaw` CLI on the instance.
- No `jq` dependency needed.

---

## 3. `config_append` — Append values to a config array

Reads an existing config array, merges new values (deduped), and writes back via `openclaw config set`. Useful for adding to arrays like `skills.load.extraDirs` without overwriting existing entries.

```yaml
- type: config_append
  path: skills.load.extraDirs
  value: '["~/.agents/skills"]'
```

**Fields:**

| Field | Required | Description |
|-------|----------|-------------|
| `path` | yes | Dot-path config key (e.g. `skills.load.extraDirs`). |
| `value` | yes | JSON array of values to append. |

**Rules:**
- Reads existing array via `openclaw config get`, merges new values, deduplicates with `jq unique`.
- Requires both `openclaw` and `jq` on the instance.
- Idempotent — running multiple times produces the same result.
- Environment variable references (`$VAR` or `${VAR}`) are expanded in both path and value.

---

## 3b. `plugin_enable` — Enable a plugin

Enables an OpenClaw plugin by id via `openclaw plugins enable`.

```yaml
- type: plugin_enable
  plugin: discord
```

**Fields:**

| Field | Required | Description |
|-------|----------|-------------|
| `plugin` | yes | Plugin identifier (e.g. `discord`, `telegram`, `slack`, `signal`). |

**Rules:**
- Requires `openclaw` CLI on the instance.
- Idempotent — enabling an already-enabled plugin is a no-op.

---

## 4. `mkdir` — Create directories

Creates one or more directories.

```yaml
- type: mkdir
  paths:
    - ~/.openclaw/workspace/memory/daily
    - ~/.openclaw/workspace/research
    - ~/.openclaw/workspace/tools
```

**Fields:**

| Field | Required | Description |
|-------|----------|-------------|
| `paths` | yes | List of directory paths to create. `~` expands to `$HOME`. |

**Rules:**
- Creates parent directories automatically (`mkdir -p`).
- Idempotent — no error if directory already exists.

---

## 5. `skill` — Install a custom skill

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

## 6. `clawhub` — Install/update ClawHub skills

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

## 7. `cron` — Register a cron job

Registers a cron job via `openclaw cron add`. Idempotent — skips if a job with the same name already exists.

```yaml
- type: cron
  name: daily-healthcheck
  schedule: "0 9 * * *"
  tz: America/New_York
  session: isolated
  message: "Run healthcheck"
  timeout_seconds: 300
  announce: true
```

**Fields:**

| Field | Required | Description |
|-------|----------|-------------|
| `name` | yes | Cron job identifier. |
| `schedule` | yes | Cron expression (e.g. `"0 9 * * *"`). |
| `message` | yes | Message to send when the job fires. |
| `tz` | no | Timezone (e.g. `America/New_York`). |
| `session` | no | Session target (e.g. `isolated`). |
| `timeout_seconds` | no | Job timeout in seconds. |
| `announce` | no | Set to `true` to enable announce delivery mode. |
| `model` | no | Model override for the cron job. |
| `thinking` | no | Set to `true` to enable thinking mode. |

**Rules:**
- Requires `openclaw` CLI on the instance.
- Checks `openclaw cron list --json` first — skips if job name already exists.

---

## 8. `exec` — Run a shell command

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

## 9. `openclaw_update` — Update OpenClaw itself

Calls `openclaw update --yes` to update OpenClaw. The CLI handles bun/npm detection automatically.

```yaml
- type: openclaw_update
  version: latest  # or "1.2.3"
```

**Fields:**

| Field | Required | Description |
|-------|----------|-------------|
| `version` | no | Target version. Defaults to `latest`. Passed as `--tag`. |

**Rules:**
- Requires `openclaw` CLI on the instance.
- Should typically be followed by a `restart` step.

---

## 11. `extension` — Install a plugin extension

Copies a plugin extension directory from the repo into `~/.openclaw/extensions/` and optionally enables it. When enabled, also registers the extension path in `plugins.load.paths` for provenance tracking.

```yaml
- type: extension
  name: inject-datetime
  enable: true
  source_dir: inject-datetime  # optional, defaults to name
```

**Fields:**

| Field | Required | Description |
|-------|----------|-------------|
| `name` | yes | Extension name (becomes destination directory name). |
| `source_dir` | no | Source directory name in `extensions/` if different from `name`. |
| `enable` | no | Auto-enable the extension via `openclaw plugins enable`. Default: `true`. |

**Rules:**
- Source directory must exist in `extensions/` in the repo.
- Destination is `~/.openclaw/extensions/<name>/`.
- Full copy — replaces existing extension entirely.
- When `enable: true`, adds the extension path to `plugins.load.paths` in `openclaw.json` for provenance.
- When `enable: true`, calls `openclaw plugins enable <name>` to activate the extension.
- Requires gateway restart for the extension to take effect.

---

## 12. `restart` — Restart the OpenClaw gateway

```yaml
- type: restart
```

**Rules:**
- Prefers `openclaw gateway restart`.
- Falls back to `systemctl --user restart openclaw-gateway` if `openclaw` binary not available.
- Non-fatal if restart fails (warns but doesn't stop the patch).
