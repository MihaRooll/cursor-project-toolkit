---
name: bootstrap-project
description: Развернуть harness toolkit в новый/существующий проект (rules, skills, hooks, papercuts). Когда просят новый проект не с нуля, bootstrap, скопировать окружение для ИИ-агентов.
---

# Bootstrap project (bootstrap-project)

## Когда использовать

- «создай новый проект с нашим окружением»
- «накати toolkit на папку X»
- старт не в голой директории, а с AI harness

## Шаги

1. Уточни путь целевого проекта (`TargetPath`) и режим:
   - `Essential` — **product** harness (по умолчанию): hooks, papercuts, `review-papercuts`, `product-core`, Essential prompting/roles/subagents
   - `Full` — плюс весь `docs/` / SOURCES / toolkit skills
   - `-WithSubmodule` — опционально `vendor/cursor-project-toolkit`
2. Запусти:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/bootstrap-into-project.ps1 -TargetPath "<path>" -Mode Essential
```

3. Открой целевую папку в Cursor.
4. Проверь: есть `product-core.mdc` + `review-papercuts`; **нет** `ship-toolkit` / `toolkit-core`.
5. Напомни: `/add-plugin cursor-team-kit`, опционально `cargo install papercuts`.
6. Не затирай чужой `AGENTS.md` без `-Force` / явной просьбы.
7. После правок harness в toolkit: `scripts/smoke-bootstrap.ps1`.

## См. также

- `docs/bootstrap-scaffold.md`
- `docs/harness-as-cursor-plugin.md`
- `project-workflow/new-project-bootstrap.md`
