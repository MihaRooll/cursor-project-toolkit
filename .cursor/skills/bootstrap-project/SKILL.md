---
name: bootstrap-project
description: Создать новый продукт («новый проект имя: цель» → new-project.ps1: папка, git, Essential, product-brief, first-chat) или накатить harness на существующую папку. Когда просят новый проект, bootstrap, накати toolkit, окружение для ИИ-агентов.
---

# Bootstrap project (bootstrap-project)

## Когда использовать

- «новый проект wifi-vpn: …» / «создай новый проект с нашим окружением»
- «накати toolkit на папку X» (уже есть директория)

## Greenfield (новый продукт)

1. Из фразы вытащи **Name** (ASCII id) и **Goal** (обязателен в чате). Если Goal нет — спроси, не запускай скрипт.
2. Запусти из корня toolkit:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/new-project.ps1 -Name "<name>" -Goal "<цель>"
```

Человек может: `.\scripts\new-project.cmd -Name … -Goal "…"`.

3. После успеха **не пиши продукт в toolkit**. Сообщи Path и шаги:
   1. File → Open Folder → Path
   2. Новый Agent-чат **в той** папке
   3. Вставить fenced-промпт из `docs/first-chat.md`
   4. `/add-plugin cursor-team-kit`
4. Если пользователь отказывается сменить workspace — не продолжай сборку продукта здесь; повтори шаг 3.

## `-AllowExisting` (занятый target)

Не «merge-safe» целиком.
- Overwrite: `product-core.mdc`, papercuts hook `.ps1`
- Merge/skip: hooks.json events; AGENTS snippet (без `-Force`); existing brief/first-chat

## Existing folder (накат harness)

1. Уточни `-TargetPath` и режим (`Essential` default; `Full` / `-WithSubmodule` только по явной просьбе).
2. Запусти:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/bootstrap-into-project.ps1 -TargetPath "<path>" -Mode Essential
```

3. Проверь: есть `product-core.mdc` + `review-papercuts`; **нет** `ship-toolkit` / `toolkit-core`.
4. Не затирай чужой `AGENTS.md` без `-Force` / явной просьбы.
5. `docs/product-brief.md` / `first-chat.md` этот путь **не** создаёт — только `new-project.ps1`.

## После правок harness в toolkit

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/parse-check-ps1.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/smoke-bootstrap.ps1
```

## См. также

- `project-workflow/new-project-bootstrap.md`
- `docs/bootstrap-scaffold.md`
- `docs/harness-as-cursor-plugin.md`
