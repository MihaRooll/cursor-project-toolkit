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
6. project-workflow/session-checklist.md
7. SOURCES.md (что уже ingest’нули)

## Что уже сделано (не повторяй с нуля)
- Подключён remote GitHub, ветка main
- AI-first docs + SRC-001…011 (GitHub beginners, Poetiq, Blume, Cursor official, prompts.chat REJECT bulk, papercuts)
- Skills (RU descriptions): add-source, distill-doc, ship-toolkit, review-papercuts, bootstrap-project
- Hooks: sessionStart, afterShellExecution→auto papercuts, stop nudge
- Windows: papercuts CLI установлен; нужен HOME=$USERPROFILE; shim scripts/papercuts.ps1
- Host .wslconfig: memory=12GB, processors=6, mirrored DNS; scripts/stabilize-wsl.ps1
- Правило среды: git/push/papercuts/winget → Windows PowerShell; WSL → Docker/Linux-only
- Коммиты (проверь `git log` / push status): bootstrap+papercuts, WSL docs

## Ограничения среды
- Агент часто в bash/WSL: `$env:VAR` ломается — для PowerShell пиши .ps1 файлы и запускай через powershell.exe
- Push иногда падает на DNS github.com — retry из Windows PowerShell
- Не force-push main; коммит/push только по просьбе пользователя
- Project skill `description` — на русском; `name` — латиница

## Приоритеты продолжения (по порядку, уточни у пользователя если неочевидно)
1. Проверить `git status` и что все коммиты на origin (push если ahead)
2. Прогнать smoke: hooks/papercuts/bootstrap на пустую тестовую папку
3. Наполнить `prompting/`, `roles/`, `subagents/` реальными AI-first шаблонами (не community dump)
4. Улучшить Essential bootstrap (что именно копировать в продукт) + опциональный git submodule toolkit
5. Рассмотреть упаковку harness как Cursor plugin (`create-plugin`)
6. Continual-learning / Team Kit — только как рекомендации install, не форкать весь kit

## Стиль работы
- Документация: блок `## For agents` первым; таблицы/чеклисты; SRC в SOURCES.md
- После повторяющегося friction → papercuts + fix в docs/rules (compound)
- Не тащи prompts.chat оптом (см. docs/prompts-chat-verdict.md)

Начни с: git status, git log -5, сверка с origin; кратко скажи что не запушено/сломано; предложи следующий конкретный шаг.
```

---
