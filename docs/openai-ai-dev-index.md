# OpenAI docs — что брать при разработке через ИИ

> **AI-first.** Курируемый индекс: не весь portal, а то, что усиливает harness / Cursor / продуктовых агентов. База: [SRC-012](../SOURCES.md), [SRC-013](../SOURCES.md).

## For agents

**Когда читать:** пользователь кинул OpenAI URL; нужен API/agent/safety/prompt совет; выбор что ingest дальше.

**Применяй:**
- Сначала [openai-gpt56-model-guidance.md](openai-gpt56-model-guidance.md)
- Для Cursor-сессий — секция «Harness / Cursor» ниже (не обязательно Responses API)
- Новое → точечный SRC + distill; не зеркалить весь developers.openai.com

**Не делай:** bulk cookbook; путать Codex UI с Cursor (похожие идеи, разные продукты).

---

## Приоритет для нашего toolkit

| Приоритет | Тема | Official | Зачем нам |
|-----------|------|----------|-----------|
| P0 | GPT-5.6 model + prompting | [latest-model](https://developers.openai.com/api/docs/guides/latest-model) | Lean prompts, autonomy, effort/pro/PTC |
| P0 | Prompt engineering | [prompt-engineering](https://developers.openai.com/api/docs/guides/prompt-engineering) | Структура промптов, structured output |
| P0 | Reasoning practices | [reasoning-best-practices](https://developers.openai.com/api/docs/guides/reasoning-best-practices) | Когда «planner» vs «doer»; не CoT-спам |
| P1 | Production | [production-best-practices](https://developers.openai.com/api/docs/guides/production-best-practices) | Keys, staging projects, latency, cost |
| P1 | Safety | [safety-best-practices](https://developers.openai.com/api/docs/guides/safety-best-practices) | HITL, moderation, safety_identifier, red team |
| P1 | Agents SDK | [Agents SDK](https://developers.openai.com/api/docs/guides/agents) | Orchestration, guardrails (если строим своих агентов) |
| P1 | Evals | [Evals](https://developers.openai.com/api/docs/guides/evals) | Living evals ↔ SRC-002 harness mindset |
| P2 | Responses API | [Responses](https://developers.openai.com/api/docs/guides/responses) | Stateful tools / multi-turn в продукте |
| P2 | Prompt caching | [prompt caching](https://developers.openai.com/api/docs/guides/prompt-caching) | Стоимость длинных system prompts |
| P2 | Multi-agent | via latest-model + Agents | Параллель workstreams |
| P2 | Codex AGENTS.md / skills | Codex docs portal | Паттерны agent config (сверять с Cursor primitives) |
| P3 | Fine-tuning / Realtime / Apps SDK | portal | Только если продукт явно про это |

---

## Harness / Cursor (без OpenAI API)

Переносимые практики из OpenAI docs → наш workflow:

| Практика | Как применять в Cursor |
|----------|------------------------|
| Lean system / rules | Короткие `.mdc` / skills; детали в `@docs/` |
| Autonomy boundaries | В `AGENTS.md` + user rules; не дублировать |
| Success criteria | В задаче / plan; verify-loop |
| Planner vs doer | Plan Mode / subagent explorer → implementer |
| HITL на high-stakes | Reviewer role; не auto-merge опасное |
| Eval before «harder model» | Не поднимать effort/pro без проверки |
| Red team | papercuts + adversarial prompts на критичных flows |

Паттерн в репо: [prompting/lean-prompts-autonomy.md](../prompting/lean-prompts-autonomy.md).

---

## Если продукт зовёт OpenAI API

Чеклист:

- [ ] Model: sol / terra / luna под нагрузку
- [ ] Responses API для tools + multi-turn
- [ ] Keys в env/secrets; staging project отдельно
- [ ] `safety_identifier` для end-users (hash)
- [ ] Latency: меньше completion tokens; streaming UX; меньшая модель где хватает
- [ ] Cost: короткий prompt, cache, batch где уместно
- [ ] Eval set до включения pro / max / PTC

---

## Источники

- https://developers.openai.com/api/docs/guides/latest-model
- Portal map: API · Agents · Production · Codex · Cookbook
- [SRC-012](../SOURCES.md) · [SRC-013](../SOURCES.md)
