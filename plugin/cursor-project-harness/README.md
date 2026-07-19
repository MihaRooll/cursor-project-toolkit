# cursor-project-harness

Cursor plugin: **product** AI harness from [cursor-project-toolkit](https://github.com/MihaRooll/cursor-project-toolkit).

## What you get

| Component | Purpose |
|-----------|---------|
| `rules/product-core.mdc` | always-on papercuts + safe ship |
| `rules/skills-ru-description.mdc` | RU skill descriptions |
| `skills/review-papercuts` | triage `.papercuts.jsonl` |
| `hooks/` | sessionStart / failed shell → papercuts / stop nudge |
| `agents/verifier` | independent verify subagent |
| `commands/install-harness-scripts` | how to get on-disk shim |

## Install (local)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File <toolkit>\scripts\install-harness-plugin.ps1
```

Or copy `plugin/cursor-project-harness` → `%USERPROFILE%\.cursor\plugins\local\cursor-project-harness` and reload Cursor.

## Still use bootstrap?

**Yes for new repos.** Plugin covers Cursor-loaded rules/skills/hooks. Bootstrap also copies prompting/roles docs, `scripts/papercuts.ps1`, and merges into existing `AGENTS.md` / `hooks.json`.

```powershell
.\scripts\bootstrap-into-project.ps1 -TargetPath C:\work\my-app -Mode Essential
```

## Version

See `.cursor-plugin/plugin.json`.
