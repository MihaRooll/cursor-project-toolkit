# Промпт для нового чата (продолжение работы)

Скопируй блок ниже в новый Agent-чат Cursor (лучше с `@AGENTS.md` и открытым этим репо).

---

```text
Ты продолжаешь работу над репозиторием cursor-project-toolkit
(https://github.com/MihaRooll/cursor-project-toolkit).

## Что это за репо
Bootstrap-каркас AI-среды разработки (не голая папка заметок):
docs AI-first → human-second, `.cursor/rules|skills|hooks`, papercuts,
скрипт `scripts/bootstrap-into-project.ps1` накатывает harness на новый продукт.
Реестр источников: SOURCES.md. Архив сбоку: archive/.

## Обязательно прочитай сначала
1. AGENTS.md
2. README.md
3. docs/bootstrap-scaffold.md
4. docs/papercuts.md
5. docs/cursor-official-index.md
6. docs/harness-as-cursor-plugin.md
7. project-workflow/session-checklist.md
8. SOURCES.md
9. project-workflow/continue-chat-prompt.md

## Что уже сделано (не повторяй с нуля)
- Remote GitHub, main; SRC-001…011
- Skills RU: add-source, distill-doc, ship-toolkit, review-papercuts, bootstrap-project
- Hooks + papercuts shim; WSL stabilize; PowerShell footguns задокументированы
- Essential = product surface (не toolkit meta-skills)
- prompting/roles/subagents AI-first шаблоны
- smoke: scripts/smoke-bootstrap.ps1 + parse-check-ps1.ps1
- Plugin: решение отложено (docs/harness-as-cursor-plugin.md); submodule флаг -WithSubmodule

## Ограничения среды
- Агент часто в bash/WSL: для PowerShell пиши .ps1 + powershell.exe
- Em-dash / `$exit:` ломают PS 5.1 — ASCII + `${var}`; parse-check перед ship
- Не force-push main; коммит/push только по просьбе
- Project skill `description` — на русском; `name` — латиница

## Приоритеты продолжения
1. git status / smoke зелёный
2. Реальные продукты: bootstrap + feedback → papercuts → compound
3. Когда ≥2 продукта на harness — scaffold Cursor plugin (create-plugin)
4. Не тащи prompts.chat оптом

## Стиль
- Docs: `## For agents` первым; SRC в SOURCES.md
- Friction → papercuts + fix

Начни с: git status, git log -5; предложи следующий конкретный шаг.
```

---
