---
name: autonomous-task
description: Автономно выполнить правку, баг, модуль или крупную фичу: выбрать T0–T4, нужных Grok/Composer/Sol субагентов, реализовать, проверить и вернуть evidence. Использовать автоматически для change/build/fix и запросов «сделай», «исправь», «реализуй».
---

# Autonomous task

Один пользовательский запрос → один bounded workflow. Main остаётся classifier, dispatcher и финальным владельцем результата.

## Сначала

1. Прочитай [tier-rubric.md](tier-rubric.md): сначала T4 overrides, затем Minimum T3, затем **самый низкий** T0–T2.
2. **T0/T1:** concise internal scope (goal, owned paths, verify commands, forbidden) + compact result — formal Task Contract не обязателен.
3. **T2+:** создай Task Contract по [contracts.md](contracts.md): Goal, AC, owned paths, verify commands, forbidden operations.
4. Не спрашивай approval для T0–T3, если нет material ambiguity. T4 → Human Gate Packet и stop.

## Routing

| Tier | Путь |
|------|------|
| T0 | Main direct: research → edit → verify (shell); без implementer/verifier/plan/contract |
| T1 | Main direct по умолчанию; implementer и/или verifier опционально (isolation, weak/expensive oracle, independence, explicit request) |
| T2 | Main → `operational-orchestrator`; stages conditional: explore, plan artifact, implementer, `adversarial-reviewer`, verifier |
| T3 | T2 + `principal-arbiter` approve **до** product writes; independent review + verification обязательны |
| T4 | Human Gate Packet; без implementer до approval |

Main выполняет T0/T1 напрямую. Для T2/T3 передай `operational-orchestrator` полный Task Contract. Для T2 orchestrator выбирает conditional stages по contract/evidence; для T3 выполняет обязательную цепочку PLAN → PRINCIPAL → IMPLEMENT → REVIEW → VERIFY. Запускает только L2 workers из таблицы. Composer не запускает reviewer/verifier.

## State machine

T0/T1: `SCOPE → IMPLEMENT → VERIFY → terminal` (Main-direct; formal CONTRACT/PLAN/REVIEW не обязательны)

T2: `CONTRACT → [EXPLORE] → [PLAN] → IMPLEMENT → [REVIEW] → [VERIFY] → terminal` (stages в `[ ]` — conditional)

T3: `CONTRACT → PLAN → PRINCIPAL → IMPLEMENT → REVIEW → VERIFY → terminal`

T4: `CONTRACT → HUMAN → HUMAN_PENDING`; reject → BLOCKED. После approve: action-only выполняет Main; code-only идёт через reviewed T2; hybrid = reviewed code → Main exact action → verify.

- T0/T1: Main может писать owned paths и запускать verify; PLAN/PRINCIPAL/REVIEW пропускаются по умолчанию.
- T2: plan artifact в `.cursor/plans/` — только если stage нужен; explore/review/verify — по решению orchestrator.
- T3: plan обязателен; Sol reject → revise packet; максимум 2 попытки, затем BLOCKED.
- T4: HUMAN_PENDING до явного решения; packet creation не означает approval.
- Review/verify rework: общий максимум 3 цикла; цикл 3 чинит только blocker.
- L2 agents не делегируют. Когда delegated — production writer один (implementer).

## Implementer vs verifier checks

- Если implementer delegated и **нет** отдельного verifier stage — implementer может запустить targeted checks из verify commands.
- Если verifier scheduled — implementer не дублирует полный verify, кроме диагностики failure.
- T0 verify — Main shell.

## Spawn packets

Каждый prompt субагенту содержит:

- `contract_id`, tier, phase;
- Goal + AC IDs;
- owned/forbidden paths;
- verify commands;
- ожидаемый return schema из [contracts.md](contracts.md);
- явный запрет расширять scope или делегировать дальше.

Для `adversarial-reviewer` не передавай reasoning автора: Task Contract + plan + diff/evidence достаточно.

## Evidence and completion

- Doc/user-facing change → Docs Impact Record ([contracts.md](contracts.md) §8): paths, map entries, validator yes/no.
- Finding без `path + lines + requirement_ref + evidence` отклони.
- Sol получает только Principal Packet: без raw logs, file dumps и tool JSON.
- `done` допустим только если Verification Record: все AC=`pass`, все exit codes=`0`, blockers=`0`.
- Main возвращает короткий Final Report: изменения, файлы, команды/exit codes, циклы, остаточные риски.

## Safety

- T4 hard overrides: production deploy, push/publish, payments, secrets, data loss, irreversible migration, destructive/external mutation.
- Не commit/push/deploy, если пользователь отдельно не просил.
- Model pins и auto-routing могут fallback/skip в normal chat; зафиксируй это как limitation, а не скрывай.
