# Cursor official — индекс ресурсов

> Формат: **AI-first → human-second**. Карта всего официального от Cursor, что стоит использовать в toolkit. Детали — в связанных docs и [SOURCES.md](../SOURCES.md).

## For agents

**Когда читать:** нужно найти официальный plugin/docs/blog по теме (rules, skills, CI, orchestration, memory, review).

**Порядок приоритета (максимум пользы):**
1. Этот индекс + [agent best practices](cursor-agent-best-practices.md)
2. [Primitives: rules / skills / AGENTS.md](cursor-primitives.md)
3. [Dynamic context](cursor-dynamic-context.md)
4. [Team Kit](cursor-team-kit.md) + [official plugins map](cursor-official-plugins.md)
5. Ставить нужные plugins через `/add-plugin …`, не копировать в archive без нужды

**Не путать:** marketplace partner-плагины (Figma, Slack…) ≠ Cursor-authored. Здесь — только author Cursor (+ pstack в том же репо, но другой автор).

---

## Стек примитивов (ментальная модель)

```
Always-on     → Rules / AGENTS.md / User Rules / Team Rules
On-demand     → Skills (+ scripts/references)
Parallel      → Subagents
External I/O  → MCP (+ skills, которые учат ими пользоваться)
Governance    → Hooks (stop loops, gates)
Package       → Plugins (marketplace / team marketplace)
```

Docs: [Rules](https://cursor.com/docs/rules) · [Skills](https://cursor.com/docs/skills) · [Plugins](https://cursor.com/docs/plugins) · [Hooks](https://cursor.com/docs/hooks) · [MCP](https://cursor.com/docs/mcp) · [Subagents](https://cursor.com/docs/subagents)

---

## Официальные plugins (author: Cursor)

Источник истины: [github.com/cursor/plugins](https://github.com/cursor/plugins).

| Plugin | Install | Зачем | Наша docs |
|--------|---------|-------|-----------|
| cursor-team-kit | `/add-plugin cursor-team-kit` | CI, PR, ship, verify, deslop | [cursor-team-kit.md](cursor-team-kit.md) |
| continual-learning | `/add-plugin continual-learning` | Авто-обновление AGENTS.md из транскриптов | [cursor-official-plugins.md](cursor-official-plugins.md) |
| thermos | `/add-plugin thermos` | Жёсткий branch review (security/quality, parallel) | plugins map |
| create-plugin | `/add-plugin create-plugin` | Scaffold/validate своих plugins | plugins map |
| agent-compatibility | `/add-plugin agent-compatibility` | Аудит «docs vs reality», startup/validation | plugins map |
| cli-for-agent | `/add-plugin cli-for-agent` | Паттерны agent-friendly CLI | plugins map |
| pr-review-canvas | `/add-plugin pr-review-canvas` | PR → Canvas для ревью | plugins map |
| docs-canvas | `/add-plugin docs-canvas` | Docs/architecture → Canvas | plugins map |
| cursor-sdk | `/add-plugin cursor-sdk` | `@cursor/sdk` — CI/automations | plugins map |
| orchestrate | `/add-plugin orchestrate` | Параллельные cloud agents (planner/worker/verifier) | plugins map |

`pstack` — в том же репо, author Lauren Tan (не Cursor); смотреть отдельно при углублении в agent workflows.

Marketplace: https://cursor.com/marketplace

---

## Must-read docs / blogs

| Ресурс | SRC | Выжимка |
|--------|-----|---------|
| [Best practices for coding with agents](https://cursor.com/blog/agent-best-practices) | SRC-005 | [cursor-agent-best-practices.md](cursor-agent-best-practices.md) |
| [Rules](https://cursor.com/docs/rules) + [Skills](https://cursor.com/docs/skills) | SRC-006 | [cursor-primitives.md](cursor-primitives.md) |
| [Dynamic context discovery](https://cursor.com/blog/dynamic-context-discovery) | SRC-007 | [cursor-dynamic-context.md](cursor-dynamic-context.md) |
| [Plugins](https://cursor.com/docs/plugins) · [blog/marketplace](https://cursor.com/blog/marketplace) | SRC-008 | этот индекс + plugins map |
| [cursor/plugins](https://github.com/cursor/plugins) (все official plugins) | SRC-009 | [cursor-official-plugins.md](cursor-official-plugins.md) |

---

## Репо, которые стоит трекать

| Repo | Зачем |
|------|--------|
| [cursor/plugins](https://github.com/cursor/plugins) | Source official plugins + plugin spec |
| [cursor/cookbook](https://github.com/cursor/cookbook) | Примеры hooks, SDK, self-hosted agents |
| [cursor/mcp-servers](https://github.com/cursor/mcp-servers) | Курируемый список MCP |
| [agentskills.io](https://agentskills.io) | Open standard Agent Skills |

---

## Рекомендуемый стартовый набор (человек + агент)

| Сделать | Зачем |
|---------|--------|
| Прочитать выжимки SRC-005…007 | Операционная модель |
| `/add-plugin cursor-team-kit` | Ежедневный ship/CI |
| `/add-plugin continual-learning` | Память prefs → AGENTS.md |
| По задаче: thermos / orchestrate / create-plugin | Review / scale / packaging |
| Держать toolkit в `docs/` AI-first | Не раздувать always-on rules |

---

## Источник

Реестр: [SOURCES.md](../SOURCES.md) (SRC-004…SRC-009)
