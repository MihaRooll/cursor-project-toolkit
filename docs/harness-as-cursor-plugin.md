# Harness как Cursor plugin

> **AI-first.** Copy/bootstrap + optional local plugin. Marketplace publish — позже.

## For agents

**Когда читать:** install plugin; сравнить bootstrap vs plugin; обновить verdict.

**Вердикт сейчас:** plugin **scaffolded и установлен локально** (`cursor-project-harness` v0.1.0). Bootstrap Essential остаётся default для on-disk файлов (prompting, `scripts/papercuts.ps1`, merge AGENTS/hooks). Marketplace submit — когда человек готов.

**Применяй:**
- Новый продукт → `bootstrap-into-project.ps1 -Mode Essential`
- Rules/skills/hooks из Cursor → `scripts/install-harness-plugin.ps1` (или reload после copy в `~/.cursor/plugins/local/`)
- Consumers: [harness-consumers.md](harness-consumers.md)

**Не делай:** форкать Team Kit; класть `ship-toolkit` / `add-source` в plugin.

---

## Критерии (статус)

| Критерий | Статус |
|----------|--------|
| Essential smoke на Windows | done |
| Product vs toolkit skills | done |
| ≥2 реальных продукта | done (TG_BOT_PRO, inkavrio_ru) |
| Semver в plugin.json | done (`0.1.0`) |
| Hooks проверены вне toolkit | done (merge в inkavrio + TG_BOT) |
| Marketplace publish | optional / human |

---

## Layout

```
plugin/cursor-project-harness/
  .cursor-plugin/plugin.json
  rules/product-core.mdc
  rules/skills-ru-description.mdc
  skills/review-papercuts/
  hooks/hooks.json
  scripts/*.ps1  (hooks + papercuts shim)
  agents/verifier.md
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
