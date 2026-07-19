# Toolkit как bootstrap-каркас нового проекта

> **AI-first.** Этот репо — не «папка с заметками», а **среда для ИИ-агентов**, которую накатывают на новый проект.

## For agents

**Когда читать:** старт нового продукта; вопрос «зачем этот репо»; команда bootstrap.

**Применяй:**
- Новый проект → skill `bootstrap-project` / `scripts/bootstrap-into-project.ps1`
- Essential = **product** harness (не toolkit meta-skills)
- Papercuts в авто: hooks логируют failed shells; ручной `add` — для всего остального
- Не начинай продукт в голой папке без harness, если пользователь ждёт toolkit-среду

**Не делай:** копировать `archive/` и весь шум без нужды (режим `Essential`); затирать AGENTS без Force; тащить `ship-toolkit` / `add-source` в продукт.

---

## Модель

```
cursor-project-toolkit  (источник истины / библиотека)
        │
        │  bootstrap-into-project.ps1
        ▼
my-new-app/             (продукт + скопированный harness)
  AGENTS.md
  .cursor/rules|skills|hooks   (product subset)
  prompting|roles|subagents    (Essential subset)
  docs/ (минимум или Full)
  .papercuts.jsonl             (растёт в продукте)
  vendor/cursor-project-toolkit  (опционально, -WithSubmodule)
```

| Режим | Что копируется |
|-------|----------------|
| Essential | product rules/skills + hooks + papercuts + ключевые docs + Essential prompting/roles/subagents |
| Full | + весь docs/SOURCES/папки toolkit + все skills/rules |
| `-WithSubmodule` | + `git submodule add` → `vendor/cursor-project-toolkit` (нужен git init в target) |

---

## Essential: product vs toolkit

| Слой | В продукт (Essential) | Только toolkit |
|------|----------------------|----------------|
| Skills | `review-papercuts` | `add-source`, `bootstrap-project`, `distill-doc`, `ship-toolkit` |
| Rules | `product-core.mdc`, `skills-ru-description.mdc` | `toolkit-core.mdc`, `docs-ai-first.mdc` |
| Prompting | README + plan/context/verify | `constraint-first.md` (Full) |
| Roles | implementer, reviewer | docs-distiller (Full) |
| Subagents | verifier brief | explorer, parallel-worker (Full) |

Шаблон rule: `templates/project-rules/product-core.mdc`.

---

## Авто-papercuts

| Слой | Поведение |
|------|-----------|
| `afterShellExecution` | exit ≠ 0 → auto `papercuts add` (лимит 8/день, dedupe) |
| `sessionStart` | HOME + короткий reminder в контекст |
| `stop` | раз в день nudge, если есть open cuts |
| Manual | `papercuts add` / shim для docs/cwd/missing tools |

---

## Команда

```powershell
cd <path-to-cursor-project-toolkit>
.\scripts\bootstrap-into-project.ps1 -TargetPath C:\work\my-app -Mode Essential
# опционально подтянуть библиотеку как submodule:
.\scripts\bootstrap-into-project.ps1 -TargetPath C:\work\my-app -Mode Essential -WithSubmodule
```

## Smoke (после правок harness)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\parse-check-ps1.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\smoke-bootstrap.ps1 -TargetPath ..\_toolkit-smoke-test
```

Ожидание: `ALL_OK` + `SMOKE PASS`; в target — product skills/rules; **нет** `ship-toolkit` / `toolkit-core`.

**Merge-safe:** чужой `AGENTS.md` → append snippet; чужой `hooks.json` → merge papercuts events (не wipe). Consumers: [harness-consumers.md](harness-consumers.md).

---

## Plugin

Local plugin: `plugin/cursor-project-harness` + `scripts/install-harness-plugin.ps1`.  
Детали: [harness-as-cursor-plugin.md](harness-as-cursor-plugin.md).

---

## Связанное

- [papercuts.md](papercuts.md)
- [harness-consumers.md](harness-consumers.md)
- [wsl-windows-stability.md](wsl-windows-stability.md) — PowerShell encoding / `${var}`
- [new-project-bootstrap.md](../project-workflow/new-project-bootstrap.md)
