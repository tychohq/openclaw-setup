# OpenClaw Setup Monorepo Review (Earlier Snapshot)

Based on the earlier snapshot (around Sun Mar 1, 2026 17:00 EST), these are the key findings.

1. `CRITICAL` `macos` setup can hard-fail when `INSTALL_OPENCLAW=true` because `REPO_DIR` is referenced but never defined in setup script.  
[macos/setup.sh:630](/Users/brenner/projects/openclaw-setup/macos/setup.sh:630) [macos/setup.sh:631](/Users/brenner/projects/openclaw-setup/macos/setup.sh:631) [macos/setup.sh:635](/Users/brenner/projects/openclaw-setup/macos/setup.sh:635)

2. `CRITICAL` `macos/setup.sh` calls scripts that are not in `macos/scripts/` (`setup-openclaw.sh`, `bootstrap-openclaw-workspace.sh`), so the OpenClaw path is broken in consolidated layout.  
[macos/setup.sh:648](/Users/brenner/projects/openclaw-setup/macos/setup.sh:648) [macos/setup.sh:660](/Users/brenner/projects/openclaw-setup/macos/setup.sh:660) [macos/README.md:218](/Users/brenner/projects/openclaw-setup/macos/README.md:218)

3. `CRITICAL` `shared/scripts/bootstrap-openclaw-workspace.sh` still expects old dirs (`openclaw-workspace/`, `openclaw-skills/`), so it skips core copy/install work in this monorepo.  
[shared/scripts/bootstrap-openclaw-workspace.sh:85](/Users/brenner/projects/openclaw-setup/shared/scripts/bootstrap-openclaw-workspace.sh:85) [shared/scripts/bootstrap-openclaw-workspace.sh:186](/Users/brenner/projects/openclaw-setup/shared/scripts/bootstrap-openclaw-workspace.sh:186)

4. `CRITICAL` `shared/scripts/audit-openclaw.sh` compares against old path layout and exits if those dirs are missing; this defeats the audit workflow.  
[shared/scripts/audit-openclaw.sh:29](/Users/brenner/projects/openclaw-setup/shared/scripts/audit-openclaw.sh:29) [shared/scripts/audit-openclaw.sh:30](/Users/brenner/projects/openclaw-setup/shared/scripts/audit-openclaw.sh:30) [shared/scripts/audit-openclaw.sh:77](/Users/brenner/projects/openclaw-setup/shared/scripts/audit-openclaw.sh:77)

5. `CRITICAL` AWS cloud-init checklist deployment clones old repos and sparse-checkouts `checklist/`; in this monorepo checklist lives under `shared/checklist/`.  
[aws/terraform/cloud-init.sh.tftpl:249](/Users/brenner/projects/openclaw-setup/aws/terraform/cloud-init.sh.tftpl:249) [aws/terraform/cloud-init.sh.tftpl:250](/Users/brenner/projects/openclaw-setup/aws/terraform/cloud-init.sh.tftpl:250) [aws/terraform/cloud-init.sh.tftpl:257](/Users/brenner/projects/openclaw-setup/aws/terraform/cloud-init.sh.tftpl:257)

6. `HIGH` AWS wizard option for config files defaults to `../../mac-mini-setup/...`; wrong default in consolidated repo context.  
[aws/setup.sh:1268](/Users/brenner/projects/openclaw-setup/aws/setup.sh:1268) [aws/setup.sh:1271](/Users/brenner/projects/openclaw-setup/aws/setup.sh:1271) [aws/setup.sh:1274](/Users/brenner/projects/openclaw-setup/aws/setup.sh:1274)

7. `HIGH` AWS README is still pre-consolidation (old repo URLs, old sibling layout, old repo names), so onboarding is misleading.  
[aws/README.md:22](/Users/brenner/projects/openclaw-setup/aws/README.md:22) [aws/README.md:118](/Users/brenner/projects/openclaw-setup/aws/README.md:118) [aws/README.md:125](/Users/brenner/projects/openclaw-setup/aws/README.md:125) [aws/README.md:162](/Users/brenner/projects/openclaw-setup/aws/README.md:162)

8. `HIGH` Top-level README is effectively empty and does not explain monorepo usage, boundaries, or entrypoints.  
[README.md:1](/Users/brenner/projects/openclaw-setup/README.md:1)

9. `HIGH` Patch system is structurally incomplete in-repo: CLI expects `patches/files/skills` under its repo root, but those dirs are absent; README also references missing step docs.  
[shared/patches/scripts/openclaw-patch:33](/Users/brenner/projects/openclaw-setup/shared/patches/scripts/openclaw-patch:33) [shared/patches/scripts/openclaw-patch:34](/Users/brenner/projects/openclaw-setup/shared/patches/scripts/openclaw-patch:34) [shared/patches/scripts/openclaw-patch:35](/Users/brenner/projects/openclaw-setup/shared/patches/scripts/openclaw-patch:35) [shared/patches/README.md:57](/Users/brenner/projects/openclaw-setup/shared/patches/README.md:57)

10. `HIGH` `aws/AGENTS.md` still documents `checklist/` as if it were inside `aws/`, now inaccurate after consolidation.  
[aws/AGENTS.md:20](/Users/brenner/projects/openclaw-setup/aws/AGENTS.md:20)

11. `MEDIUM` Multiple docs still instruct users to use `mac-mini-setup` paths/repo names, creating cross-platform confusion in `shared` templates.  
[shared/workspace/bootstrap/setup-context.md:3](/Users/brenner/projects/openclaw-setup/shared/workspace/bootstrap/setup-context.md:3) [shared/workspace/bootstrap/secrets-guide.md:57](/Users/brenner/projects/openclaw-setup/shared/workspace/bootstrap/secrets-guide.md:57) [shared/cron-jobs/README.md:10](/Users/brenner/projects/openclaw-setup/shared/cron-jobs/README.md:10)

12. `MEDIUM` Duplicate PRD content exists in two places with identical hash (`meta/PRDs/PRD-patches.md` and `shared/patches/docs/PRD.md`), increasing drift risk.  
[meta/PRDs/PRD-patches.md](/Users/brenner/projects/openclaw-setup/meta/PRDs/PRD-patches.md) [shared/patches/docs/PRD.md](/Users/brenner/projects/openclaw-setup/shared/patches/docs/PRD.md)

13. `MEDIUM` Some executable scripts are committed non-executable (`openclaw-patch`, clawdstrike helper scripts), which will fail direct invocation.  
[shared/patches/scripts/openclaw-patch](/Users/brenner/projects/openclaw-setup/shared/patches/scripts/openclaw-patch) [shared/skills/clawdstrike/scripts/collect_verified.sh](/Users/brenner/projects/openclaw-setup/shared/skills/clawdstrike/scripts/collect_verified.sh) [shared/skills/clawdstrike/scripts/redact_helpers.sh](/Users/brenner/projects/openclaw-setup/shared/skills/clawdstrike/scripts/redact_helpers.sh)

14. `MEDIUM` Broken internal markdown references detected in snapshot (`meta/PROJECT.md` links, missing patch docs link).  
[meta/PROJECT.md](/Users/brenner/projects/openclaw-setup/meta/PROJECT.md) [shared/patches/README.md:57](/Users/brenner/projects/openclaw-setup/shared/patches/README.md:57)

15. `MEDIUM` Naming drift across platforms (`GATEWAY_AUTH_TOKEN` vs `OPENCLAW_GATEWAY_TOKEN`, `DISCORD_BOT_TOKEN` vs `DISCORD_TOKEN`) makes shared templates less portable than intended.  
[aws/setup.sh:1250](/Users/brenner/projects/openclaw-setup/aws/setup.sh:1250) [shared/scripts/setup-openclaw.sh:289](/Users/brenner/projects/openclaw-setup/shared/scripts/setup-openclaw.sh:289) [aws/.env.example:37](/Users/brenner/projects/openclaw-setup/aws/.env.example:37) [shared/config/openclaw-env.template:20](/Users/brenner/projects/openclaw-setup/shared/config/openclaw-env.template:20)

16. `MEDIUM` Two Slack manifest sources differ (`aws/templates/...` vs `shared/config/...`) with overlapping intent, likely accidental duplication/drift.  
[aws/templates/slack-app-manifest.json](/Users/brenner/projects/openclaw-setup/aws/templates/slack-app-manifest.json) [shared/config/slack-app-manifest.json](/Users/brenner/projects/openclaw-setup/shared/config/slack-app-manifest.json)

17. `LOW` Root `.gitignore` is sparse for this repo type (no `terraform.tfvars`, no local generated setup artifacts like `.slack-app-state.json`, etc.), which increases accidental commit risk.  
[.gitignore:1](/Users/brenner/projects/openclaw-setup/.gitignore:1)

18. `LOW` `macos/bootstrap.sh` still hard-resets an existing clone to `origin/main`; this is risky behavior for local edits in setup repo clones.  
[macos/bootstrap.sh:65](/Users/brenner/projects/openclaw-setup/macos/bootstrap.sh:65)

## Open Questions / Assumptions

1. Is `shared/` intended to be the single source of truth, with `aws/` and `macos/` consuming it? If yes, most path fixes should point there.
2. Do you want `aws/` and `macos/` to remain independently clonable, or strictly monorepo-internal modules?
3. Should `meta/` keep historical references intentionally, or be normalized to current repo names/paths?

## Short Summary

- Biggest issues are not cosmetic: there are several hard path breakages from pre-consolidation layout, plus one real runtime bug in `macos/setup.sh`.
- README/documentation is currently the largest contributor to user error because it still teaches old repos and old folder structures.
- Fixing path/source-of-truth consistency first will eliminate most downstream issues quickly.

PR/issue URL: N/A (review-only, no PR created).
