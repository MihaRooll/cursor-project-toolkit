# Cursor official plugins — карта (выжимка)

> **AI-first.** Источник: [SRC-009](../SOURCES.md) — [cursor/plugins](https://github.com/cursor/plugins) · [Marketplace](https://cursor.com/marketplace). Team Kit детально: [cursor-team-kit.md](cursor-team-kit.md).

## For agents

**Когда читать:** выбор plugin под задачу; рекомендация пользователю что поставить.

**Применяй:** `/add-plugin <name>` · не форкать в archive по умолчанию (MIT на GitHub).  
**Не делай:** ставить всё сразу — шум skills; бери по задаче.

---

## Карта «задача → plugin»

| Задача | Plugin |
|--------|--------|
| CI / PR / ship / deslop / verify harness | `cursor-team-kit` |
| Память prefs/фактов из чатов → AGENTS.md | `continual-learning` |
| Жёсткий security/quality review ветки | `thermos` |
| Параллельные cloud agents на большую цель | `orchestrate` |
| Свой plugin для команды | `create-plugin` |
| «Доки врут / агент не стартует» аудит | `agent-compatibility` |
| Проектируем CLI под агентов | `cli-for-agent` |
| Ревью PR визуально (Canvas) | `pr-review-canvas` |
| Architecture/runbook как Canvas | `docs-canvas` |
| Автоматизации на `@cursor/sdk` | `cursor-sdk` |

---

## Краткие карточки

### continual-learning
- Hook `stop` → skill → subagent `agents-memory-updater`
- Пишет только `## Learned User Preferences` и `## Learned Workspace Facts` (plain bullets)
- Cadence (default): ≥10 turns, ≥120 min, transcript mtime advanced
- State: `.cursor/hooks/state/continual-learning*.json`
- Install: `/add-plugin continual-learning`

### thermos
- Thermo-nuclear branch review: security/correctness, harsh rubrics, parallel subagents, optional merge-ready PR
- Близок по духу к thermo-nuclear skill из Team Kit, но как отдельный review pack

### orchestrate
- Fan-out через Cursor SDK: planners → workers → verifiers, handoffs на disk/git
- Нужны: `bun`, `CURSOR_API_KEY`; Slack опционален
- Invoke: skill + `cli.ts kickoff "<goal>"`
- Не для мелких правок — для крупных параллельных целей

### create-plugin
- Scaffold/validate `.cursor-plugin/plugin.json`, skills/rules/agents/hooks/MCP
- Когда этот toolkit созреет до installable plugin — стартовая точка

### agent-compatibility
- CLI scans + agents: startup, validation, docs vs reality
- Полезно перед тем как считать docs «готовыми для ИИ»

### cli-for-agent
- Flags, help+examples, pipelines, errors, idempotency, dry-run
- Связь с Team Kit `control-cli` и harness-мышлением

### pr-review-canvas / docs-canvas
- Рендер PR/docs в Cursor Canvas (группы по важности, TOC, diagrams)
- UI-слой ревью/объяснения, не замена git flow

### cursor-sdk
- Runtime, auth, streaming, MCP, errors для programmatic agents (CI, bots)
- Blog: [Build programmatic agents with the Cursor SDK](https://cursor.com/blog/typescript-sdk)

---

## Packaging reminder

Plugin = rules + skills + agents + commands + hooks + MCP в одном бандле.  
Docs: [Plugins](https://cursor.com/docs/plugins) · Blog: [Extend Cursor with plugins](https://cursor.com/blog/marketplace).

---

## Источник

https://github.com/cursor/plugins · https://cursor.com/marketplace · [SRC-008](../SOURCES.md) · [SRC-009](../SOURCES.md)
