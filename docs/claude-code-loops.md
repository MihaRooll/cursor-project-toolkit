# Loop engineering (Claude Code / Anthropic)

> **AI-first.** Источник: [SRC-014](../SOURCES.md) — [Getting started with loops](https://claude.com/blog/getting-started-with-loops) · анонс [X/@ClaudeDevs](https://x.com/ClaudeDevs/status/2074208949205881033).

## For agents

**Когда читать:** пользователь говорит «loop», «крути пока не…», recurring CI/PR, proactive triage; дизайн harness vs one-shot prompt.

**Определение (Anthropic):** loop = агент **повторяет циклы работы**, пока не выполнено **stop condition**.

**Применяй:**
- Начинай с самого простого типа loop
- Hand off то, что сейчас bottleneck: check → stop condition → trigger → весь prompt
- Stop criteria делай **детерминированными** (tests, score, queue empty), не «достаточно хорошо»
- Качество loop = harness вокруг: clean codebase, verify skills, docs, second-agent review
- Ошибка в одном прогоне → encode в skill/rule (compound), не только hotfix

**Не делай:** сложный proactive loop на exploratory задачу; крутить без turn/time cap; путать Claude `/goal`/`/loop` с Cursor (маппинг ниже).

---

## Четыре типа

| Loop | Hand off | Trigger | Stop | Когда | Claude primitive |
|------|----------|---------|------|-------|------------------|
| Turn-based | verification check | user prompt | agent «done» / needs context | short, exploratory | skills / self-verify |
| Goal-based | stop condition | manual prompt | goal met **or** max turns | measurable done | `/goal` |
| Time-based | schedule trigger | interval | cancel / external done | recurring / poll external | `/loop`, `/schedule` |
| Proactive | full prompt (no human realtime) | event or schedule | per-task goal; routine until off | triage, deps, ops streams | compose + auto mode |

Пример goal: `/goal get the homepage Lighthouse score to 90 or above, stop after 5 tries.`
Пример time: `/loop 5m check my PR, address review comments, and fix failing CI`

---

## Cursor / toolkit mapping

Claude Code commands ≠ Cursor 1:1. Переноси **идею**:

| Идея loop | В Cursor / этом toolkit |
|-----------|-------------------------|
| Turn + verify skill | `prompting/verify-loop.md` · skill с quantitative checks · browser MCP |
| Goal + turn cap | Явный DoD в задаче + Plan; agent grind до tests green; stop hook / papercuts nudge |
| Time / schedule | CI schedule, cron, cloud agents, Cursor Automations (если есть) |
| Proactive compose | Hooks + scheduled jobs + Team Kit / orchestrate; не держать человека в realtime |
| Second-agent review | `roles/reviewer.md` · `subagents/verifier.md` · thermos / code review plugin |
| Compound failure → system | papercuts → fix docs/rules/skills |

---

## Quality (система вокруг loop)

1. Clean codebase — агент копирует существующие паттерны
2. Self-verify skills — quantitative (tests, console zero errors, Lighthouse)
3. Docs reachable — up-to-date practices
4. Fresh-context reviewer — не тот же agent, что писал код

Verify-skill pattern (смысл): не считать UI done после edit; server + interact + console + metrics; fail → fix → rerun.

---

## Token / cost

| Рычаг | Действие |
|-------|----------|
| Right primitive | Не multi-agent на мелкую задачу |
| Clear stop | Done criteria + caps |
| Pilot | Сначала slice, не 100 agents сразу |
| Scripts | Deterministic → script, не re-reason |
| Interval | Не poll чаще, чем меняется сигнал |
| Model | Smaller для routine; capable для judgment |

---

## Getting started (человек)

1. Найди задачу, где **ты** bottleneck
2. Спроси: могу ли отдать check / stop / trigger / весь prompt?
3. Запусти простейший loop → смотри stall / over-reach → iterate harness

---

## Источник

- https://claude.com/blog/getting-started-with-loops
- https://x.com/ClaudeDevs/status/2074208949205881033
- [SRC-014](../SOURCES.md)
