# Toolkit как bootstrap-каркас нового проекта

> **AI-first.** Этот репо — не «папка с заметками», а **среда для ИИ-агентов**, которую накатывают на новый проект.

## For agents

**Когда читать:** старт нового продукта; вопрос «зачем этот репо»; команда bootstrap.

**Применяй:**
- Новый проект → skill `bootstrap-project` / `scripts/bootstrap-into-project.ps1`
- В целевом репо должны появиться: `.cursor/rules|skills|hooks`, `AGENTS.md`, papercuts scripts, ключевые docs
- Papercuts в авто: hooks логируют failed shells; ручной `add` — для всего остального
- Не начинай продукт в голой папке без harness, если пользователь ждёт toolkit-среду

**Не делай:** копировать `archive/` и весь шум без нужды (режим `Essential`); затирать AGENTS без Force.

---

## Модель

```
cursor-project-toolkit  (источник истины / библиотека)
        │
        │  bootstrap-into-project.ps1
        ▼
my-new-app/             (продукт + скопированный harness)
  AGENTS.md
  .cursor/rules|skills|hooks
  docs/ (минимум или Full)
  .papercuts.jsonl      (растёт в продукте)
```

| Режим | Что копируется |
|-------|----------------|
| Essential | harness + ключевые docs + papercuts scripts |
| Full | + весь docs/SOURCES/папки toolkit |

## Авто-papercuts

| Слой | Поведение |
|------|-----------|
| `afterShellExecution` | exit ≠ 0 → auto `papercuts add` (лимит 8/день, dedupe) |
| `sessionStart` | HOME + короткий reminder в контекст |
| `stop` | раз в день nudge, если есть open cuts |
| Manual | `papercuts add` / shim для docs/cwd/missing tools |

## Команда

```powershell
cd <path-to-cursor-project-toolkit>
.\scripts\bootstrap-into-project.ps1 -TargetPath C:\work\my-app -Mode Essential
```

---

## Связанное

- [papercuts.md](papercuts.md)
- [new-project-bootstrap.md](../project-workflow/new-project-bootstrap.md)
