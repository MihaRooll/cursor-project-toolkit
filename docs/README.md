# docs/ — основная документация

Главный слой toolkit для агентов и людей. Сырые полные копии — в [`archive/`](../archive/README.md). Реестр внешних ссылок — [`SOURCES.md`](../SOURCES.md).

Исполняемый harness: [`AGENTS.md`](../AGENTS.md) · [`.cursor/rules/`](../.cursor/rules/) · [`.cursor/skills/`](../.cursor/skills/) (`add-source`, `distill-doc`, `ship-toolkit`).

Документация пишется **сначала для ИИ-агентов**, затем для людей.

## Приоритет аудитории

1. **ИИ** — контекст для Cursor / субагентов: факты, команды, чеклисты, правила «когда делать X»
2. **Люди** — краткие пояснения и ссылки на источники, без воды

## Как писать выжимки (стандарт)

Каждый файл в `docs/` по возможности содержит:

| Блок | Для кого | Содержание |
|------|----------|------------|
| `## For agents` | ИИ | Когда читать файл, что применять, запреты/ограничения |
| Факты / таблицы / команды | ИИ → люди | Структурировано, без повествования |
| Чеклист | ИИ → люди | Проверяемые шаги |
| Источник | люди | URL оригинала |

### Правила стиля

- Короткие императивы: «делай X», «не делай Y»
- Таблицы и списки вместо абзацев
- Один файл = одна тема; заголовок = поисковый ключ
- Не дублировать полный оригинал — только actionable выжимку
- Людские «истории» и мотивация — в 1–2 строки или в ссылку на источник

### Skills этого репо

- `description` в `SKILL.md` — **на русском** (меню `/`)
- `name` / папка — латиница
- Стандарт: [skills-russian-descriptions.md](skills-russian-descriptions.md)

## Индекс

| Файл | Тема | SRC | Когда агенту читать |
|------|------|-----|---------------------|
| [skills-russian-descriptions.md](skills-russian-descriptions.md) | RU descriptions для skills | — | Новый/правка `SKILL.md` |
| [prompts-chat-verdict.md](prompts-chat-verdict.md) | prompts.chat — не bulk-ingest | SRC-010 | Предлагают скачать community prompts |
| [papercuts.md](papercuts.md) | Papercuts CLI — жалобы агентов | SRC-011 | Friction, tooling footguns, triage backlog |
| [bootstrap-scaffold.md](bootstrap-scaffold.md) | Toolkit → новый проект | — | Bootstrap harness в продукт |
| [cursor-official-index.md](cursor-official-index.md) | Карта всего official Cursor | SRC-004…009 | Старт: найти plugin/docs/blog |
| [cursor-agent-best-practices.md](cursor-agent-best-practices.md) | Операционный manual агента | SRC-005 | Plan, context, rules/skills, workflows |
| [cursor-primitives.md](cursor-primitives.md) | Rules / Skills / AGENTS.md | SRC-006 | Создание rules и skills |
| [cursor-dynamic-context.md](cursor-dynamic-context.md) | Dynamic context discovery | SRC-007 | Дизайн docs/skills без раздувания контекста |
| [cursor-official-plugins.md](cursor-official-plugins.md) | Official plugins map | SRC-009 | Какой plugin ставить под задачу |
| [cursor-team-kit.md](cursor-team-kit.md) | Cursor Team Kit | SRC-004 | CI, PR, ship, control-cli/ui, deslop |
| [github-for-beginners-essentials.md](github-for-beginners-essentials.md) | Git / GitHub essentials | SRC-001 | Репо, ветки, PR, Issues, Actions, security, OSS |
| [harness-over-weights-rsi.md](harness-over-weights-rsi.md) | Harness > weights, RSI | SRC-002 | Архитектура toolkit, eval vs бенчмарки |
| [blume-ai-ready-docs.md](blume-ai-ready-docs.md) | Blume AI-ready docs | SRC-003 | Публикация docs: llms.txt, MCP, сайт |
