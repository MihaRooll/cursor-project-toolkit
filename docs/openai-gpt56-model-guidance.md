# GPT-5.6 — model guidance (OpenAI)

> **AI-first.** Источник: [SRC-012](../SOURCES.md) — [Using GPT-5.6 / latest-model](https://developers.openai.com/api/docs/guides/latest-model).

## For agents

**Когда читать:** выбор модели OpenAI API; миграция с 5.4/5.5; промпты для агентов/инструментов; pro mode / PTC / multi-agent.

**Применяй (в Cursor / продукте):**
- Lean prompts: одна инструкция один раз; меньше tools; убирать шум → лучше качество и дешевле
- Явные autonomy / approval boundaries (см. шаблон ниже)
- Goal + constraints + success criteria; не расписывать каждый микрошаг (intent understanding сильнее)
- Для API: Responses API; `reasoning.effort` осознанно; pro только если eval показывает выигрыш

**Не делай:** «think step by step» на reasoning-моделях; дублировать «ask first» везде (лишние паузы); считать PTC нужным только из‑за параллельных вызовов.

---

## Модельное семейство

| Slug / alias | Роль |
|--------------|------|
| `gpt-5.6` → `gpt-5.6-sol` | Flagship capability |
| `gpt-5.6-terra` | Баланс качество/цена |
| `gpt-5.6-luna` | Высокий объём, дешевле/быстрее |

Миграция с 5.5/5.4: сохранить текущий `reasoning.effort`, затем сравнить **тот же** и **на уровень ниже**.

---

## `reasoning.effort`

| Effort | Когда |
|--------|--------|
| `none` | Latency baseline |
| `low` | Latency-sensitive; иногда лучше `none` при tool use |
| `medium` | Default / баланс |
| `high` / `xhigh` | Есть измеренный quality gain |
| `max` | Самые жёсткие quality-first задачи; сравнивай с `xhigh` |

`reasoning.mode: "pro"` — больше работы модели → один финальный ответ; **не** отдельный Pro slug. Effort выбирай независимо. Default effort при omit = `medium`.

---

## Что нового (кратко)

| Фича | Смысл для продуктов |
|------|---------------------|
| Programmatic Tool Calling | JS в hosted runtime обрабатывает много tool results → маленький structured result |
| Multi-agent [beta] | Параллельные subagents + synthesize (как ultra в Codex) |
| Explicit prompt caching | Точные cache breakpoints; writes = 1.25× uncached |
| Persisted reasoning | `reasoning.context`: `auto` / `all_turns` / `current_turn` |
| Frontend design | Лучше layout / hierarchy / design judgment |
| Intent understanding | Меньше микроменеджмента шагов; больше domain + constraints |

Safeguards: cyber/biology classifiers могут блокировать или паузить dual-use; для end-users — `safety_identifier` (hashed).

---

## Prompting (самое полезное для агентской разработки)

### Lean prompts

- Убери повтор и лишние examples по одному блоку → eval
- Одна формулировка правила
- Только релевантные tools, короткие descriptions
- Internal coding-agent sample: +10–15% scores, −41–66% tokens (directional)

### Autonomy / approval (шаблон)

```
For requests to answer, explain, review, diagnose, or plan, inspect the relevant
materials and report the result. Do not implement changes unless the request also
asks for them.

For requests to change, build, or fix, make the requested in-scope local changes
and run relevant non-destructive validation without asking first.

Require confirmation for external writes, destructive actions, purchases, or a
material expansion of scope.
```

Safe local: read files, logs, edit in-scope code, run tests. Не повторять «ask first» десять раз.

### Verbosity / стиль

- GPT-5.6 короче 5.5 по умолчанию — «Be concise» может быть лишним или вредным
- API: `text.verbosity` = `low` | `medium` | `high`
- Короткие ответы: явно что сохранить (conclusion, evidence, caveat, next action)

### PTC — когда да / нет

**Да:** filter/join/rank/aggregate больших промежуточных tool outputs.
**Нет:** один вызов; маленький intermediate; каждый результат меняет решение; нужен approval; нужны citations как native artifacts.

---

## Связь с toolkit

| OpenAI идея | У нас |
|-------------|--------|
| Lean prompts | `prompting/` + короткие rules |
| Autonomy boundaries | `AGENTS.md`, `product-core`, user rules |
| Multi-agent | Cursor Task/subagents; `subagents/` |
| Eval before pro/max | papercuts + verify-loop, не vanity benchmarks |
| AGENTS.md (Codex) | наш `AGENTS.md` / bootstrap template |

Карта остальных docs: [openai-ai-dev-index.md](openai-ai-dev-index.md).

---

## Источник

https://developers.openai.com/api/docs/guides/latest-model · [SRC-012](../SOURCES.md)
