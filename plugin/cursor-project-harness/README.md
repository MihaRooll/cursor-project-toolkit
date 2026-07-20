# cursor-project-harness

Cursor plugin: **product** AI harness from [cursor-project-toolkit](https://github.com/MihaRooll/cursor-project-toolkit).

## What you get

| Component | Purpose |
|-----------|---------|
| `rules/product-core.mdc` | always-on papercuts + safe ship |
| `rules/skills-ru-description.mdc` | RU skill descriptions |
| `rules/autonomous-orchestration.mdc` | T0–T4 routing + evidence gates |
| `rules/project-docs-lifecycle.mdc` | living docs + docs-map updates |
| `skills/review-papercuts` | triage `.papercuts.jsonl` |
| `skills/autonomous-task` | one-request plan/implement/review/verify workflow |
| `skills/maintain-project-docs` | update docs-map + run validator |
| `skills/configure-project-integrations` | propose/dry-run MCP integrations (read-only) |
| `skills/browser-verify` | native Browser MCP checks; Human Gate on auth/untrusted |
| `skills/setup-project-environment` | doctor → propose toolchain; no silent installs |
| `hooks/` | sessionStart (stage+doctor context) / failed shell → papercuts / stop nudge |
| `agents/` | Grok orchestrator/reviewer/verifier, Composer implementer, Sol arbiter |
| `commands/install-harness-scripts` | how to get on-disk shim |

## Install (local)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File <toolkit>\scripts\install-harness-plugin.ps1
```

Or copy `plugin/cursor-project-harness` → `%USERPROFILE%\.cursor\plugins\local\cursor-project-harness` and reload Cursor.

## Still use bootstrap?

**New repos (greenfield):** from toolkit clone → `new-project.ps1` / `.cmd`
(folder + git + Essential + product-brief + first-chat + docs-map + project-state). Plugin alone is not enough.

**Existing folder:** Essential bootstrap for on-disk prompting/roles, `scripts/papercuts.ps1`, `scripts/project-doctor.ps1`,
AGENTS snippet append, hooks.json merge.

**Full bootstrap** adds MCP profile templates (`templates/mcp/`), native control examples (`templates/cursor/`), security/memory guides, and `validate-mcp-profiles.ps1`. Essential never ships active MCP or native configs.

```powershell
# greenfield
.\scripts\new-project.cmd -Name my-app -Goal "цель"

# existing
.\scripts\bootstrap-into-project.ps1 -TargetPath C:\work\my-app -Mode Essential

# opt-in Full (MCP + native templates + docs)
.\scripts\bootstrap-into-project.ps1 -TargetPath C:\work\my-app -Mode Full
```

## Version

See `.cursor-plugin/plugin.json` (**0.5.0** — Wave 3 environment/doctor/browser-verify/setup-project-environment).
