# Autonomous agent orchestration

> **AI-first.** Один change/build/fix запрос → минимальный достаточный multi-agent pipeline. Источники: Cursor docs + Anthropic/OpenAI engineering reports (toolkit registry: SRC-023/024).

## For agents

**Когда читать:** выбрать T0–T4; делегировать Grok/Composer/Sol; спор о Plan Mode; нельзя заявлять done без evidence.

**Применяй:**

1. Main классифицирует по `.cursor/skills/autonomous-task/tier-rubric.md`. **Число файлов само по себе не повышает tier.**
2. T0/T1: Main direct — research, edit, verify; formal Task Contract/plan/implementer не обязательны.
3. T1 mechanical multi-file с низким blast/ambiguity/coupling и сильным oracle остаётся T1.
4. T2/T3 — через `operational-orchestrator` когда нужны staged agents; T2 stages conditional (explore/plan/implement/review/verify).
5. T3: Sol Principal Packet до product writes; independent review + verification обязательны.
6. T4: Human Gate Packet.
7. Production writer один **когда delegated**; Main may write on T0/T1 direct path. Параллельны только read-only Explore scouts.
8. Completion = acceptance + deterministic checks + zero blockers.

**Не делай:** считать auto-routing, model pin, Sol gate или T4 stop платформенной гарантией; отправлять premium-модели raw logs; путать official `/add-plugin orchestrate` с этим on-disk policy harness; повышать tier только из-за file count.

---

## Routing

| Tier | Путь | Human |
|------|------|-------|
| T0 | Main direct: research → edit → shell verify | нет |
| T1 | Main direct по умолчанию; implementer/verifier опционально | нет |
| T2 | Main → Grok L1; conditional explore/plan/implement/review/verify L2 | нет |
| T3 | T2 + Sol Principal Packet до product writes + review + verify | нет, если Sol approve |
| T4 | Human Gate Packet; без implementer до approval | да |

Main — единственный classifier и user-facing completion owner. L2 agents не делегируют. Composer не запускает reviewer/verifier.

## Models

| Agent | Model | Permission |
|-------|-------|------------|
| operational-orchestrator | `cursor-grok-4.5-high-fast` | пишет только `.cursor/plans/**` |
| implementer | `composer-2.5-fast` | sole product writer **when delegated**; Main writes T0/T1 direct |
| adversarial-reviewer | `cursor-grok-4.5-high-fast` | readonly; T2 conditional, T3 required |
| verifier | `cursor-grok-4.5-high-fast` | shell checks; T2+ default when verify needed |
| principal-arbiter | `gpt-5.6-sol-medium` | readonly, T3 only |

Cursor может заменить configured model из-за plan/admin/Max restrictions. Pin = intent, не абсолютная гарантия. Grok/Composer расходуют включённый Cursor pool; Sol подключается только для T3.

## Plan Mode vs internal plan

- UI Plan Mode: пользователь явно попросил сначала только план → человек нажимает Build/approve.
- T4 change/build/fix: Human Gate Packet в обычном workflow; это не UI Plan Mode.
- Internal plan artifact: T3 **обязателен**; T2 **conditional** → `.cursor/plans/<contract_id>.plan.md`.
- T0/T1 plan artifact не нужен.

## Evidence protocol

Finding валиден только с:

```yaml
path: path/to/file
lines: 10-20
requirement_ref: AC-1|INV-1
evidence: reproducible observation
```

Review ограничен тремя общими implement→review→verify циклами; цикл 3 — blocker-only. Sol reject разрешает максимум две версии Principal Packet.

Done строго:

- каждый acceptance criterion = pass;
- каждый required command exit code = 0;
- open blockers = 0;
- Main relays Verification Record и создаёт короткий Final Report; VR создаёт verifier when scheduled, иначе Main (T0/T1 direct, T4 action-only).

Полные schemas: [contracts.md](../.cursor/skills/autonomous-task/contracts.md).

Только в clone самого toolkit: `scripts/validate-orchestration.ps1 -SelfTest`; локальный `scripts/smoke-bootstrap.ps1` запускает validator автоматически. В bootstrapped Essential/Full products validator и его repo fixtures намеренно отсутствуют.

## Premium packet

Sol получает invariants, validation plan и короткие `{path, lines, excerpt}` refs. Не передавай raw terminal logs, полные файлы, tool JSON или историю всех агентов.

## Guarantees and limits

| Есть | Нет в normal chat |
|------|--------------------|
| Rules/skills/agents, model intent, nesting, deterministic scripts | гарантированного auto-trigger |
| Fresh subagent contexts | гарантированного Sol-before-write |
| Human approval policy | hard T4 filesystem/shell block |
| `.cursor/plans/` artifacts | durable workflow state machine |

Hard routing, budgets and mutation gates — следующий этап через hooks/SDK после eval 10–20 задач.

## Official orchestrate plugin

Этот harness работает внутри текущего product repo. `/add-plugin orchestrate` — отдельный official cloud/SDK workflow для параллельных cloud agents; не заменяй один другим автоматически.

---

## Sources

- [Cursor Subagents](https://cursor.com/docs/subagents) / [Plan Mode](https://cursor.com/docs/agent/plan-mode) / [models](https://cursor.com/docs/models-and-pricing) — SRC-023
- [Anthropic multi-agent engineering](https://www.anthropic.com/engineering/multi-agent-research-system); [OpenAI harness](https://openai.com/index/harness-engineering/) / [Symphony](https://openai.com/index/open-source-codex-orchestration-symphony/) — SRC-024
