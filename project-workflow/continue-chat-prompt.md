# Промпт для нового чата (продолжение работы)

Скопируй блок ниже в новый Agent-чат Cursor (лучше с `@AGENTS.md` и открытым этим репо).

План hardening: [`new-project-hardening-plan.md`](new-project-hardening-plan.md).

---

```text
Ты продолжаешь работу над репозиторием cursor-project-toolkit
(https://github.com/MihaRooll/cursor-project-toolkit).

## Что это за репо
Bootstrap-каркас AI-среды разработки (не голая папка заметок):
docs AI-first → human-second, `.cursor/rules|skills|hooks`, papercuts,
`scripts/new-project.ps1` = greenfield; `scripts/bootstrap-into-project.ps1` = harness на существующую папку.
Реестр источников: SOURCES.md. Архив сбоку: archive/.

## Обязательно прочитай сначала
1. AGENTS.md
2. README.md
3. docs/bootstrap-scaffold.md
4. project-workflow/new-project-hardening-plan.md   ← СЛЕДУЮЩИЙ РАБОЧИЙ ПЛАН
5. project-workflow/new-project-bootstrap.md
6. scripts/new-project.ps1
7. docs/papercuts.md
8. docs/harness-as-cursor-plugin.md
9. docs/harness-consumers.md
10. project-workflow/session-checklist.md
11. SOURCES.md (SRC-001…022)
12. project-workflow/continue-chat-prompt.md

## Что уже сделано (не повторяй с нуля)
- Remote GitHub; main = origin (последний merge: PR #2 live consumers + local plugin)
- Skills RU: add-source, distill-doc, ship-toolkit, review-papercuts, bootstrap-project
- Hooks + papercuts shim; WSL stabilize; PowerShell footguns (em-dash, ${exit})
- Essential = product-only; merge-safe AGENTS snippet + hooks.json merge
- Local plugin: plugin/cursor-project-harness + install-harness-plugin.ps1
- Live consumers: TG_BOT_PRO, inkavrio_ru
- NEW: greenfield flow v2 реализован и smoke PASS:
  - scripts/new-project.ps1 + .cmd
  - bootstrap -SkipNext
  - templates/product-brief.md + templates/first-chat.md
  - skill bootstrap-project (greenfield vs existing)
  - smoke-bootstrap секция === Smoke new-project === (TEMP + finally)
- 3 цикла × 5 субагентов: вердикт GO-with-patch — см. new-project-hardening-plan.md

### Ingest + new-project в working tree (часто ЕЩЁ НЕ ЗАКОММИЧЕНО — проверь git status)
SRC-012…022 docs + prompting; SOURCES/docs/README; new-project scripts/templates/skill/docs/smoke.
Не коммить/не пушь без явной просьбы («зашей» / /ship-toolkit).

## СЛЕДУЮЩАЯ ЗАДАЧА (приоритет)
Выполни hardening по project-workflow/new-project-hardening-plan.md по порядку:

1. NP-01 blocker: Get-FinalPath (Win32) — canonicalize Parent/Target ДО New-Item; fail-closed; smoke junction Parent→toolkit must fail
2. NP-02/03 blocker: SSOT docs — harness-as-cursor-plugin.md + toolkit-core.mdc + AGENTS layers (greenfield=new-project)
3. NP-04: честный -AllowExisting (не «merge-safe»)
4. NP-05: smoke top-5 (Essential mustAbsent brief; refuse non-empty; AllowExisting preserve brief; Name in brief; AGENTS H1)
5. NP-06…09 по остатку бюджета (title patch, Marketplace day-0 plugin, skills-ru sync, optional SkipNext HOME)

После правок .ps1: parse-check-ps1.ps1 затем smoke-bootstrap.ps1.

Потом (если пользователь даст OK): wifi-vpn через new-project.cmd + строка в harness-consumers.md.
Или ship: ветка + PR для ingest+new-project+hardening — только по «зашей».

## Ограничения среды
- PowerShell: .ps1 ASCII; powershell.exe -NoProfile -ExecutionPolicy Bypass
- Em-dash / $exit: ломают PS 5.1 — ASCII + ${var}
- Не force-push main; secrets out
- Skill description на русском
- Не тащи community dumps / Full packs в Essential
- new-project.ps1 только из клона toolkit, не «ожидай» его внутри продукта

## Политики
- Official/actionable → SRC + AI-first docs
- Community dump → REJECT bulk
- UI Skills / Matt / Addy / ReMe / clean-code-js → on demand в продуктах

## Стиль
- ## For agents первым; таблицы; индекс docs/README.md
- Friction → papercuts
- Один конкретный следующий шаг в ответе человеку

Начни с: git status, git log -5, сверка origin; кратко что в working tree; затем сразу NP-01 (или спроси «зашей» если пользователь хочет сначала commit без hardening).
```

---
