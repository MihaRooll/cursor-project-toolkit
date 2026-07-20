# Claude Code prompt library — выжимка

> **AI-first.** Источник: [SRC-015](../SOURCES.md) — [Prompt library](https://code.claude.com/docs/en/prompt-library). Official Anthropic starters, не community dump.

## For agents

**Когда читать:** нужен starter-промпт под фазу SDLC; пользователь кинул code.claude.com/prompt-library; сравнение с prompts.chat.

**Применяй:**
- Брать **паттерны** (таблица ниже) + 1–2 starter’а под задачу
- В Cursor: копируй текст в Agent; `{slots}` замени сам; `@file` вместо Claude `@`
- Повторяющийся starter → skill / `prompting/*.md`, не копипаст в каждый чат
- После успеха → conventions в `AGENTS.md` (у них: CLAUDE.md)

**Не делай:** зеркалить всю библиотеку в `archive/`; путать с [prompts.chat REJECT bulk](prompts-chat-verdict.md) — здесь official + workflow-focused.

**Вердикт:** **ACCEPT patterns + selective starters**. Full catalog остаётся на сайте.

---

## Что делает промпты рабочими (meta)

| Паттерн | Смысл | Мини-пример |
|---------|--------|-------------|
| Outcome, not steps | Цель; агент сам найдёт файлы | `add rate limiting to the public API and make sure existing tests still pass` |
| Way to check work | run/test/compare/verify в том же промпте | `write the migration, run it, confirm schema matches` |
| Point at a reference | Совпадение с существующим паттерном | `settings page that follows the same layout as the profile page` |
| Measurable target | Метрика + порог = unambiguous done | `get the bundle size under 200KB and show what you removed` |
| Give the artifact | `@` лог/скрин/план, не пересказ | `why is the build failing? @build.log` |
| Say how to answer | format / audience / length | `explain … as HTML with a diagram, then open in browser` |

Связь с нами: [lean-prompts-autonomy](../prompting/lean-prompts-autonomy.md) · [verify-loop](../prompting/verify-loop.md) · [agent-loops](../prompting/agent-loops.md) · [plan-then-build](../prompting/plan-then-build.md).

---

## Карта библиотеки (фазы)

| sdlc | Категории (cat) | Типичное |
|------|-----------------|----------|
| discover | Onboard, Understand | overview, where is X, blast radius, git history |
| design | Plan, Prototype | plan no-edit, interview→SPEC, mockup→prototype |
| build | Implement, Test, Refactor, Review, Steer | pattern-match, TDD, migrate, PR review, course-correct |
| ship | Git, Release | commit, PR, release notes, CI |
| operate | Debug, Incident, Data, Automate | fix from error, logs, skill/hook from recurring |

Источники карточек у Anthropic: Common workflows, Best practices, Teams use Claude Code, Scaling guide.

---

## Starters для Cursor (кураторский минимум)

Подставь свои значения. Не нужен полный каталог.

### Discover

```
give me an overview of this codebase: architecture, key directories, and how the pieces connect
```

```
where do we {behavior}?
```

```
what would break if I deleted {target}?
```

```
which files would I need to touch to {change}?
```

### Design

```
plan how to refactor the {target} to {goal}. list the files you would change, but don't edit anything yet
```

```
I want to build {feature}. interview me about implementation, UX, edge cases, and tradeoffs until we have covered everything, then write the spec to SPEC.md
```

### Build / Test

```
look at how {example} is implemented to understand the pattern, then build {new} the same way
```

```
write tests for {path}, run them, and fix any failures
```

```
write tests for {feature} first, then implement it until they pass
```

```
optimize {target} to bring {metric} from {current} down to under {goal}
```

### Review / Steer / Ship

```
review my uncommitted changes and flag anything that looks risky before I commit
```

```
review PR #{pr} and summarize what changed, then list any concerns
```

```
{correction}. remember this for the rest of the session / encode in AGENTS.md if it should persist
```

### Operate

```
here's the error / @log. find the root cause, fix it, and run the relevant tests
```

```
this task keeps recurring: {task}. turn it into a skill (or short checklist) so next time it's one command
```

Полный UI-каталог: https://code.claude.com/docs/en/prompt-library

---

## После того как промпт сработал

| Шаг | Claude Code | У нас |
|-----|-------------|--------|
| Повторяемый | skill → `/command` | `.cursor/skills/…` |
| Конвенции | CLAUDE.md | `AGENTS.md` + rules |
| Крупный риск | plan mode | Plan Mode / plan-then-build |
| Self-check loop | `/goal` | measurable done + verify-loop / agent-loops |

---

## vs prompts.chat

| | Claude prompt library | prompts.chat |
|--|----------------------|--------------|
| Автор | Anthropic official | community |
| Фокус | coding agent workflows | всё подряд |
| Ingest | patterns + curated starters | **REJECT bulk** |
| Docs | этот файл | [prompts-chat-verdict.md](prompts-chat-verdict.md) |

---

## Источник

https://code.claude.com/docs/en/prompt-library · [SRC-015](../SOURCES.md)
llms.txt index: https://code.claude.com/docs/llms.txt
