# agent-loops

> Паттерн из Anthropic loop engineering ([SRC-014](../SOURCES.md)). «Design loops, not just prompts.»

## For agents

**Когда:** задача длиннее одного turn; recurring CI/PR; пользователь хочет «крути пока не зелёное».

**Применяй:**
1. Выбери тип: turn / goal / time / proactive (см. таблицу в `docs/claude-code-loops.md`)
2. Сформулируй **measurable stop** + **cap** (tries / time)
3. Подключи verify (tests, lint, browser) — не «кажется ок»
4. Fail → encode в skill/rule, не только починить этот раз

**Не делай:** infinite grind без cap; proactive на exploratory scope.

---

## Mini decision

| Ситуация | Тип |
|----------|-----|
| Exploring / deciding | Turn + verify skill |
| Know what done looks like | Goal + max tries |
| External changes on a clock | Time / schedule |
| Recurring well-defined stream | Proactive compose |

---

## Goal prompt template (Cursor)

```
Done when: <deterministic check>
Max iterations: <N>
Each iteration: implement → run <verify cmd> → fix failures
Stop early if blocked on human decision; ask once with options.
```

---

## См. также

- [docs/claude-code-loops.md](../docs/claude-code-loops.md)
- [verify-loop.md](verify-loop.md)
