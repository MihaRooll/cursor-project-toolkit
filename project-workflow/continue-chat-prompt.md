# Промпт для нового чата (реализация fast-loop)

Скопируй блок ниже в **новый** Agent-чат Cursor с открытым репозиторием `cursor-project-toolkit`.

---

```text
Ты реализуешь fast-development harness для cursor-project-toolkit
(https://github.com/MihaRooll/cursor-project-toolkit).

## Явная авторизация (из handoff-сессии 2026-07-23)
Пользователь разрешает ПОЛНУЮ реализацию Waves 0–3 по архитектуре ниже.
ЗАПРЕЩЕНО без отдельного явного OK: commit, push, merge, tag, release,
branch protection, plugin install/remove, запись в user profile, LICENSE,
смена model pin / cost-class, внешние мутации.

## Обязательно прочитай сначала (focused reads, не whole-repo scan)
1. AGENTS.md
2. docs/fast-development-harness-plan.md          ← архитектура SSOT
3. docs/session-handoff-2026-07-23.md            ← контекст сессии, риски, git state
4. docs/project-state.md
5. .cursor/plans/toolkit-fast-loop-v1.plan.md    ← wave-таблицы, если файл есть (gitignored)
6. project-workflow/continue-chat-prompt.md

## Контракт
- НЕ возобновляй toolkit-fast-loop-v1 (BLOCKED: cycle:4 в metadata).
- Создай НОВЫЙ контракт toolkit-fast-loop-v2, cycle: 1, tier T3.
- Один bounded principal gate (Sol) перед product writes — без повторного premium planning/research.
- Архитектуру бери из docs/fast-development-harness-plan.md + v1 plan body.
- Не делай новый web research / plan review, если main @ 997fad5 не изменился materially.

## Модели (явный запрос slug)
- Sole implementer / writer: composer-2.5-fast
- operational-orchestrator, adversarial-reviewer, verifier: cursor-grok-4.5-high-fast
- T3 principal (один вызов при необходимости): gpt-5.6-sol-medium — только bounded gate, не повтор planning

## Оркестрация (efficient agents)
- Один writer (implementer); Main не product-writes T0–T3.
- Scouts/explore: max 0 по умолчанию; только при distinct unknown — один scout на uncertainty.
- Не дублируй scouts; resume того же агента на rework.
- Compact Work Packets ≤2k; без raw logs и full file dumps в packets.
- Читай output files точечно, не целиком репо.

## TodoWrite
Используй TodoWrite для wave/slice tracking.
Останавливайся только при definitive blocker (Human Gate, missing command, ownership violation).
Статус человеку — кратко.

## Порядок реализации
1. Wave 0 baseline (no writes) — wall-clock, registry observation, MIT intent ask
2. Wave 1 oracle slice → Grok adversarial-reviewer + verifier
3. Wave 2 CI slice → Grok review + verify
4. Wave 3A → 3B → 3D policy/hygiene slices → Grok review каждый; финальный full verify
Не начинай Waves 4–6.

## Wave 1 напоминание (кратко)
- verify-harness Quick (each check once) + Full = Quick + smoke-bootstrap -OracleOnly
- Ownership-safe TEMP GUID; reject pre-existing; hard-reject junction; mandatory -SkipUserHome
- parse ALL tracked .ps1; recovery in Quick; STAGE_OK fail-closed; deterministic-only success text
- verify-harness NOT on Essential/Full copy lists

## Wave 2 напоминание
- Один windows-latest job, unconditional, verify-harness -Profile Full
- SHA-pinned actions; contents:read; no paths/matrix/cache/secrets

## Human Gates — STOP и спроси
- branch protection / required checks
- plugin user-profile mutation
- root LICENSE
- model pin / cost-class change
- commit / push / release

## Verify (после каждого slice)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\validate-project-docs.ps1 -ProjectRoot .
git diff --check
+ slice-specific commands из v2 plan / fast-development-harness-plan.md

Начни: git status; подтверди base; создай toolkit-fast-loop-v2 cycle 1 plan; TodoWrite; Wave 0.
```

---
