# Harness как Cursor plugin

> **AI-first.** Copy/bootstrap + optional local plugin. Marketplace publish — позже.

## For agents

**Когда читать:** install plugin; сравнить bootstrap vs plugin; обновить verdict.

**Вердикт сейчас:** plugin scaffold в repo — `cursor-project-harness` (semver in `plugin/cursor-project-harness/.cursor-plugin/plugin.json`) с autonomous-task, maintain-project-docs, configure-project-integrations, browser-verify, setup-project-environment, model-pinned agents. Локальная копия может быть старее: после update запусти installer и reload Cursor. Bootstrap Essential остаётся default для on-disk docs/scripts/AGENTS merge; native control **templates** и MCP templates только Full.

**Static vs runtime evidence:** mirror hash checks, orchestration SelfTest, and Essential smoke prove **on-disk copy integrity** only. **Runtime coexistence** (plugin hooks + product hooks in Cursor IDE, load order, reload behavior) is **unverified** until a runtime coexistence protocol exists (Wave 4+). Do not claim hooks “verified in consumers” from static merge alone.

**Применяй:**
- Greenfield (новый продукт) → `scripts/new-project.ps1` / `.cmd` / skill `bootstrap-project`
- Уже есть папка → `scripts/bootstrap-into-project.ps1 -TargetPath … -Mode Essential`
- Rules/skills/hooks в Cursor → `scripts/install-harness-plugin.ps1` (или reload после copy в `~/.cursor/plugins/local/`)
- Consumers: [harness-consumers.md](harness-consumers.md)

**Не делай:** форкать Team Kit; класть `ship-toolkit` / `add-source` в plugin.

---

## Критерии (статус)

| Критерий | Статус |
|----------|--------|
| Essential smoke на Windows | done (static/deterministic) |
| Product vs toolkit skills | done |
| ≥2 реальных продукта | done (TG_BOT_PRO, inkavrio_ru) |
| Repo semver in plugin.json | done; live install проверяй после installer |
| Hooks static merge in consumers | done (on-disk copy) |
| Hooks runtime coexistence in Cursor | **unverified** — pending runtime protocol |
| Marketplace publish | optional / human |

### Static hash/smoke vs runtime (normative)

| Layer | What validators prove | Status |
|-------|----------------------|--------|
| **Static** | Byte mirrors (`validate-orchestration`), Essential smoke, parse/dry-run | verified by deterministic scripts |
| **Runtime** | Plugin + product hooks both active; IDE reload; hook event order | **unverified** — manual Cursor protocol not standardized yet |

Do not promote “hooks verified outside toolkit” to runtime verified without explicit coexistence evidence.

---

## Layout

```
plugin/cursor-project-harness/
  .cursor-plugin/plugin.json
  rules/product-core.mdc
  rules/skills-ru-description.mdc
  rules/autonomous-orchestration.mdc
  rules/project-docs-lifecycle.mdc
  skills/review-papercuts/
  skills/autonomous-task/
  skills/maintain-project-docs/
  skills/configure-project-integrations/
  skills/browser-verify/
  skills/setup-project-environment/
  hooks/hooks.json
  scripts/*.ps1  (hooks + papercuts shim)
  agents/  (orchestrator, implementer, reviewer, verifier, Sol arbiter)
  commands/install-harness-scripts.md
  README.md
```

Install:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\install-harness-plugin.ps1
```

→ `%USERPROFILE%\.cursor\plugins\local\cursor-project-harness` → reload Cursor.

---

## Copy vs Plugin

| Need | Use |
|------|-----|
| On-disk prompting/docs/shim + merge AGENTS | bootstrap Essential |
| Cursor-loaded rules/skills/hooks everywhere | local plugin |
| Team marketplace | publish later (cursor.com/marketplace/publish) |

Официально: [Plugins](https://cursor.com/docs/plugins) · [reference](https://cursor.com/docs/reference/plugins) · SRC-008/009.

---

## Связанное

- [bootstrap-scaffold.md](bootstrap-scaffold.md)
- [harness-consumers.md](harness-consumers.md)
- [cursor-official-plugins.md](cursor-official-plugins.md)
