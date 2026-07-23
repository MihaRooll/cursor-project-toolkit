# Промпт для нового чата (продолжение после Waves 0–6)

Скопируй блок ниже в **новый** Agent-чат Cursor с открытым репозиторием `cursor-project-toolkit`.

---

```text
Ты продолжаешь работу над cursor-project-toolkit после завершённой сессии 2026-07-23.
Waves 0–6 tooling/runtime УЖЕ реализованы. НЕ делай повторный research и НЕ переimplementируй волны.

## Сначала прочитай (focused reads — не whole-repo scan)
1. AGENTS.md
2. docs/session-handoff-2026-07-23.md          ← финальный git/CI/runtime state
3. docs/project-state.md                       ← milestones + evidence_pending gates
4. docs/fast-development-harness-plan.md       ← архитектура SSOT (reference only)
5. project-workflow/continue-chat-prompt.md

## Git / PR / CI — проверь live, не доверяй устаревшим SHA в чате
- Branch: feat/complete-fast-development-harness
- PR #4 open: https://github.com/MihaRooll/cursor-project-toolkit/pull/4
- Observed head: 9b684cc773468571c5efc4185c686f52d50aaee2
- Observed green CI: run 29994496765 (toolkit-verify)
- main: strict required check toolkit-verify
Начни с: git status; git log -1; сверка с PR head и последним CI на GitHub.

## Контракт продолжения
- НЕ возобновляй toolkit-fast-loop-v1 (BLOCKED: cycle:4).
- НЕ создавай toolkit-fast-loop-v2/v3 заново — они done.
- Допустимые задачи: maintain PR #4, docs/evidence slices, collect graduation corpora,
  Human-Gated merge/publish — только по явному OK пользователя.
- Graduation gates (A/B 6–10 tasks, planner p95/20 CI/30–60 patches/zero misses) —
  evidence_pending, не повод re-implement shadow tooling.

## Human Gates — STOP и спроси заново (prior chat approvals НЕ переносятся)
commit, push, merge, tag, release, branch protection, plugin install/remove,
запись в user profile, root LICENSE, model pin / cost-class, strict hooks promotion,
destructive/external writes.

## Модели и делегирование
- Первый spawn subagent: явно укажи requested model slug в Task call.
- resume того же agent: model НЕ передавай — UI может показать Auto; reuse prior agent/model.
- Pin/routing — best-effort intent, не platform enforcement; фиксируй фактическую модель когда observable.
- Main — единственный owner spawns и user-facing completion.
- implementer sole writer T0–T3; implementer НИКОГДА не spawnит Task/subagents/reviewer/verifier —
  если нужна делегация, верни управление Main.
- L2 agents never delegate.

## Оркестрация (efficient)
- Scouts default 0; один writer; compact Work Packets ≤2k; без raw logs.
- Читай output files точечно.

## Verify (после docs/harness touch)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\validate-project-docs.ps1 -ProjectRoot .
git diff --check
+ при harness edits: scripts\verify-harness.ps1 -Profile Quick (local) / Full перед merge claim

Начни: git status; сверка PR #4 + live CI; краткий статус что уже done vs evidence_pending; спроси цель пользователя.
```

---
