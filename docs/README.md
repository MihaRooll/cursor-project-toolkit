# docs/ — основная документация

Главный слой toolkit для агентов и людей. Сырые полные копии — в [`archive/`](../archive/README.md). Реестр внешних ссылок — [`SOURCES.md`](../SOURCES.md).

Исполняемый harness: [`AGENTS.md`](../AGENTS.md) · [`.cursor/rules/`](../.cursor/rules/) · [`.cursor/skills/`](../.cursor/skills/) (`autonomous-task`, `maintain-project-docs`, `review-papercuts` + toolkit-only skills).

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
| [living-documentation.md](living-documentation.md) | Living docs + docs-map index | — | Material doc change; validator; maintain skill |
| [docs-map-schema.md](docs-map-schema.md) | Schema for docs/docs-map.json | — | Create/edit map; validator errors |
| [project-integrations.md](project-integrations.md) | Essential vs day-0 living docs wiring | — | Bootstrap/plugin integration questions |
| [project-environment.md](project-environment.md) | Surfaces: IDE/CLI/Cloud/Automation/SCM | SRC-029 | Cross-PC setup; runtime vs build secrets |
| [cursor-native-controls.md](cursor-native-controls.md) | permissions/sandbox/env/BUGBOT/ignore/Browser | SRC-029/030 | Opt-in native controls; Essential ships none active |
| [project-state.md](project-state.md) | Phase, milestones, next checks | — | Session stage; setup skill; doctor advisory |
| [memory-and-obsidian.md](memory-and-obsidian.md) | Memory authority + Obsidian vault rules | SRC-026/027 | Conflict resolution; Automation memory; Obsidian opt-in |
| [mcp-security.md](mcp-security.md) | MCP placement, pins, Human Gate | SRC-025/028 | Propose/validate MCP; local vs cloud; untrusted tool I/O |
| [harness-evidence-and-enforcement.md](harness-evidence-and-enforcement.md) | Living-eval + strict hook promotion | SRC-029 | Full opt-in enforcement; failClosed; Cloud hook limits |
| [harness-as-cursor-plugin.md](harness-as-cursor-plugin.md) | Copy vs plugin vs submodule | SRC-008/009 | Упаковка harness; local plugin install |
| [harness-consumers.md](harness-consumers.md) | Живые продукты с Essential | — | Где накатан harness; feedback loop |
| [openai-gpt56-model-guidance.md](openai-gpt56-model-guidance.md) | GPT-5.6 latest-model | SRC-012 | Модели, effort/pro/PTC, lean prompts |
| [openai-ai-dev-index.md](openai-ai-dev-index.md) | OpenAI docs для AI-dev | SRC-013 | Что читать из portal; P0–P3 |
| [claude-code-loops.md](claude-code-loops.md) | Loop engineering (Anthropic) | SRC-014 | Turn/goal/time/proactive; map → Cursor |
| [claude-code-prompt-library.md](claude-code-prompt-library.md) | Claude Code prompt library | SRC-015 | Patterns + curated starters; vs prompts.chat |
| [ui-skills.md](ui-skills.md) | UI Skills catalog / CLI | SRC-016 | Design-eng skills; `npx ui-skills start`; selective |
| [ponytail.md](ponytail.md) | Ponytail lazy-senior mode | SRC-017 | YAGNI ladder; Cursor copy rule; opt-in product |
| [clean-code-javascript.md](clean-code-javascript.md) | Clean Code для JS/TS | SRC-018 | Naming/functions/SOLID/async; review rubric; on demand |
| [addyosmani-agent-skills.md](addyosmani-agent-skills.md) | Addy Osmani agent-skills pack | SRC-019 | Lifecycle skills; `npx skills add`; selective, не Essential |
| [mattpocock-skills.md](mattpocock-skills.md) | Matt Pocock skills | SRC-020 | Grill/CONTEXT/TDD/tickets; composable; selective, не Essential |
| [reme-agent-memory.md](reme-agent-memory.md) | ReMe agent memory | SRC-021 | Markdown memory layer; CLI/MCP; vs continual-learning; opt-in |
| [security-in-session-cursor-vs-claude.md](security-in-session-cursor-vs-claude.md) | In-session security: Claude vs Cursor | SRC-022 | Bugbot `/review-security`, thermos, Semgrep hooks; нет 1:1 plugin |
| [autonomous-agent-orchestration.md](autonomous-agent-orchestration.md) | Autonomous T0–T4 routing: Grok/Composer/Sol | SRC-023/024 | Один change/build/fix запрос; subagents, gates, evidence, stop policy |
| [recovery-escalation.md](recovery-escalation.md) | Recovery R0a shadow/manual protocol | SRC-031 | Explicit `/recovery-escalation`; stuck predicates; promotion gate R0b |
| [wsl-windows-stability.md](wsl-windows-stability.md) | Стабильный WSL2 на Windows | — | .wslconfig, когда использовать WSL |
| [cursor-official-index.md](cursor-official-index.md) | Карта всего official Cursor | SRC-004…009 | Старт: найти plugin/docs/blog |
| [cursor-agent-best-practices.md](cursor-agent-best-practices.md) | Операционный manual агента | SRC-005 | Plan, context, rules/skills, workflows |
| [cursor-primitives.md](cursor-primitives.md) | Rules / Skills / AGENTS.md | SRC-006 | Создание rules и skills |
| [cursor-dynamic-context.md](cursor-dynamic-context.md) | Dynamic context discovery | SRC-007 | Дизайн docs/skills без раздувания контекста |
| [cursor-official-plugins.md](cursor-official-plugins.md) | Official plugins map | SRC-009 | Какой plugin ставить под задачу |
| [cursor-team-kit.md](cursor-team-kit.md) | Cursor Team Kit | SRC-004 | CI, PR, ship, control-cli/ui, deslop |
| [github-for-beginners-essentials.md](github-for-beginners-essentials.md) | Git / GitHub essentials | SRC-001 | Репо, ветки, PR, Issues, Actions, security, OSS |
| [harness-over-weights-rsi.md](harness-over-weights-rsi.md) | Harness > weights, RSI | SRC-002 | Архитектура toolkit, eval vs бенчмарки |
| [blume-ai-ready-docs.md](blume-ai-ready-docs.md) | Blume AI-ready docs | SRC-003 | Публикация docs: llms.txt, MCP, сайт |
