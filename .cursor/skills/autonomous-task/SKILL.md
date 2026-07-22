---
name: autonomous-task
description: Автономно выполнить правку, баг, модуль или крупную фичу: выбрать T0–T4, делегировать Composer/Grok/Sol субагентов, реализовать, проверить и вернуть evidence. Использовать автоматически для change/build/fix и запросов «сделай», «исправь», «реализуй».
---

# Autonomous task

Один пользовательский запрос → один bounded workflow. Main — classifier, dispatcher и финальный владелец результата; **Main never product-writes T0–T3**.

## Сначала

1. Прочитай [tier-rubric.md](tier-rubric.md): сначала T4 overrides, затем Minimum T3, затем **самый низкий** T0–T2.
2. **T0/T1:** compact Work Packet (goal, owned paths, verify commands, forbidden) — formal Task Contract не обязателен.
3. **T2+:** создай Task Contract по [contracts.md](contracts.md): Goal, AC, owned paths, verify commands, forbidden operations.
4. Не спрашивай approval для T0–T3, если нет material ambiguity. T4 → Human Gate Packet и stop.

## Routing

| Tier | Путь |
|------|------|
| T0 | Main Work Packet → Composer `implementer` → targeted deterministic checks; без plan/Grok review/Sol principal |
| T1 | Main Work Packet → Composer `implementer` → Grok `verifier`; без plan; mechanical bounded multi-file may stay T1 |
| T2 | Main contract → Grok `operational-orchestrator`; stages conditional: explore, plan artifact, implementer, `adversarial-reviewer`, verifier |
| T3 | T2 + `principal-arbiter` approve **до** product writes; independent review + verification обязательны |
| T4 | Human Gate Packet; без implementer до approval |

Main делегирует product writes только Composer implementer (T0–T3). Для T2/T3 передай `operational-orchestrator` полный Task Contract. T2 orchestrator выбирает conditional stages; T3 — обязательная цепочка PLAN → PRINCIPAL → IMPLEMENT → REVIEW → VERIFY. Composer не запускает reviewer/verifier.

## State machine

T0: `WORK_PACKET → IMPLEMENT → VERIFY(targeted)` (implementer targeted checks; no separate verifier)

T1: `WORK_PACKET → IMPLEMENT → VERIFY(verifier)` (Grok verifier required)

T2: `CONTRACT → [EXPLORE] → [PLAN] → IMPLEMENT → [REVIEW] → [VERIFY] → terminal` (stages в `[ ]` — conditional)

T3: `CONTRACT → PLAN → PRINCIPAL → IMPLEMENT → REVIEW → VERIFY → terminal`

T4: `CONTRACT → HUMAN → HUMAN_PENDING`; reject → BLOCKED. После approve: action-only выполняет Main; code-only идёт через reviewed T2; hybrid = reviewed code → Main exact action → verify.

- T0/T1: plan artifact не нужен; Main never product-writes.
- T2: plan artifact в `.cursor/plans/` — только если stage нужен; explore/review/verify — по решению orchestrator.
- T3: plan обязателен; Sol reject → revise packet; максимум 2 попытки, затем BLOCKED.
- T4: HUMAN_PENDING до явного решения; packet creation не означает approval.
- Review/verify rework: общий максимум 3 цикла; цикл 3 чинит только blocker.
- L2 agents не делегируют. Production writer один (implementer).

## Work Packet + context budgets

Main создаёт compact Work Packet (см. [contracts.md](contracts.md) §0). Context budgets — **best-effort**, не platform-enforced:

| Packet | Max tokens |
|--------|------------|
| Work/Scope Packet | ≤2k |
| L2 Spawn Packet | ≤8k |
| Scout return | ≤4k |
| Final Report | ≤1.5k |

Запрещено в packets: raw logs, full files, chat history, tool JSON dumps.

## Implementer vs verifier checks

- T0: implementer запускает targeted checks; отдельного verifier нет.
- T1+: Grok verifier обязателен на T1; T2+ — когда stage scheduled.
- Если verifier scheduled — implementer не дублирует полный verify, кроме диагностики failure.
- Verifier/reviewer **не создают** `_v_*.txt` или temp evidence в product root.

## Spawn packets

Каждый prompt субагенту содержит:

- `contract_id`, tier, phase;
- Goal + AC IDs;
- owned/forbidden paths;
- verify commands;
- ожидаемый return schema из [contracts.md](contracts.md);
- явный запрет расширять scope или делегировать дальше.

Для `adversarial-reviewer` не передавай reasoning автора: Task Contract + plan + diff/evidence достаточно.

## Model pins (best-effort)

| Role | Model |
|------|-------|
| implementer | `composer-2.5-fast` |
| operational-orchestrator, adversarial-reviewer, verifier | `cursor-grok-4.5-high-fast` |
| principal-arbiter | `gpt-5.6-sol-medium` (T3-only) |

Pin = intent; Cursor может fallback/skip в normal chat.

## Evidence and completion

- Doc/user-facing change → Docs Impact Record ([contracts.md](contracts.md) §8): paths, map entries, validator yes/no.
- Finding без `path + lines + requirement_ref + evidence` отклони.
- Sol получает только Principal Packet: без raw logs, file dumps и tool JSON.
- `done` допустим только если Verification Record: все AC=`pass`, все exit codes=`0`, blockers=`0`.
- Main возвращает короткий Final Report (≤1.5k): изменения, файлы, команды/exit codes, циклы, остаточные риски.

## Safety

- T4 hard overrides: production deploy, push/publish, payments, secrets, data loss, irreversible migration, destructive/external mutation.
- Не commit/push/deploy, если пользователь отдельно не просил.
- Model pins и auto-routing могут fallback/skip в normal chat; зафиксируй это как limitation, а не скрывай.
