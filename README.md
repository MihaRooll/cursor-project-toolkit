# Cursor Project Toolkit

## Зачем это

Это **каркас среды разработки для ИИ-агентов**: документация + rules/skills/hooks + papercuts.

Его **накатывают на новый проект**, чтобы не начинать в голой папке, а сразу работать в настроенном harness (агент знает правила, умеет логировать friction, видит AI-first docs).

**Новый проект (happy path):** из клона toolkit — `.\scripts\new-project.cmd -Name <name> -Goal "<цель>"` (или в чате: «новый проект \<name\>: \<цель\>») → Open Folder → вставить `docs/first-chat.md` → `/add-plugin cursor-team-kit`.
**Уже есть папка (advanced):** `.\scripts\bootstrap-into-project.ps1 -TargetPath <path> -Mode Essential` — только harness, без brief.
**Подробнее:** skill `/bootstrap-project` · [`project-workflow/new-project-bootstrap.md`](project-workflow/new-project-bootstrap.md) · [`docs/bootstrap-scaffold.md`](docs/bootstrap-scaffold.md) (в продуктах скрипт `new-project` не ожидается).

## Аудитория docs

**Сначала ИИ, потом люди.** Стандарт: [`docs/README.md`](docs/README.md).

## Live harness

| Что | Где |
|-----|-----|
| Agent instructions | [`AGENTS.md`](AGENTS.md) · шаблон продукта: [`templates/project-AGENTS.md`](templates/project-AGENTS.md) |
| Rules / skills | [`.cursor/rules/`](.cursor/rules/) · [`.cursor/skills/`](.cursor/skills/) |
| Hooks (авто) | [`.cursor/hooks.json`](.cursor/hooks.json) — sessionStart, failed-shell → papercuts, stop nudge |
| Papercuts | CLI или [`scripts/papercuts.ps1`](scripts/papercuts.ps1) · [`docs/papercuts.md`](docs/papercuts.md) |
| Bootstrap | [`scripts/new-project.ps1`](scripts/new-project.ps1) / `.cmd` (greenfield) · [`scripts/bootstrap-into-project.ps1`](scripts/bootstrap-into-project.ps1) (existing) |
| WSL stabilize | [`scripts/stabilize-wsl.ps1`](scripts/stabilize-wsl.ps1) · [`docs/wsl-windows-stability.md`](docs/wsl-windows-stability.md) |
| Workflow | [`project-workflow/`](project-workflow/) |

### Marketplace (в Cursor)

```
/add-plugin cursor-team-kit
/add-plugin continual-learning
```

## Авто-papercuts

| Когда | Что происходит |
|-------|----------------|
| Упала shell-команда | Hook пишет cut в `.papercuts.jsonl` (лимит/dedupe) |
| Старт сессии | HOME + короткий reminder |
| Конец сессии (раз/день) | Nudge открыть backlog, если есть cuts |
| Остальной friction | Агент/ты: `papercuts add "…"` |

Разбор: `/review-papercuts`.

## Что собираем

| Область | Содержание |
|--------|------------|
| Промптирование / роли / субагенты | [`prompting/`](prompting/) · [`roles/`](roles/) · [`subagents/`](subagents/) — AI-first шаблоны (не community dump) |
| Rules & skills | Исполняемый harness; Essential = product subset |
| Ведение проектов | Bootstrap, DoD, papercuts loop |
| Документация | AI-first выжимки + [`SOURCES.md`](SOURCES.md) |
| Plugin | Local: [`plugin/cursor-project-harness`](plugin/cursor-project-harness) · `scripts/install-harness-plugin.ps1` · [`docs/harness-as-cursor-plugin.md`](docs/harness-as-cursor-plugin.md) |
| Consumers | [`docs/harness-consumers.md`](docs/harness-consumers.md) (TG_BOT_PRO, inkavrio_ru) |

## Слои знаний

| Слой | Где | Роль |
|------|-----|------|
| Основное | `docs/`, `.cursor/` | То, что едет в проекты (Essential) |
| Архив | `archive/` | Сырьё сбоку, не обязательно копировать |

## Структура

```
cursor-project-toolkit/
├── scripts/new-project.ps1 / .cmd   # greenfield
├── scripts/bootstrap-into-project.ps1
├── templates/project-AGENTS.md
├── AGENTS.md / SOURCES.md
├── .cursor/rules|skills|hooks
├── docs/                     # AI-first
├── project-workflow/
└── prompting|roles|subagents|…
```

Карта Cursor official: [`docs/cursor-official-index.md`](docs/cursor-official-index.md)

---

**Миссия:** каждый новый проект стартует как полноценная AI-native среда, а не как пустая директория.
