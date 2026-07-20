# Новый проект из toolkit (не голая папка)

## Happy path

**В чате toolkit:** `новый проект <name>: <цель>` (Goal обязателен) → skill `/bootstrap-project`.

**Или из клона toolkit:**

```bat
.\scripts\new-project.cmd -Name my-app -Goal "одна фраза цели"
```

Дальше:

1. File → Open Folder → Path из stdout
2. Новый Agent-чат в **продукте**
3. Вставить промпт из `docs/first-chat.md`
4. `/add-plugin cursor-team-kit`

## Что считается успехом

- [ ] Папка создана, есть `.git`
- [ ] Есть `.cursor/hooks.json`, `AGENTS.md`, `product-core.mdc`, `review-papercuts`
- [ ] **Нет** toolkit-only skills (`ship-toolkit`, `add-source`, …)
- [ ] Есть `docs/product-brief.md` и `docs/first-chat.md`
- [ ] Работа продолжается в workspace продукта, не в toolkit

## Advanced

| Нужда | Команда |
|-------|---------|
| Уже есть папка — только harness | `.\scripts\bootstrap-into-project.ps1 -TargetPath <path> -Mode Essential` |
| Полная библиотека docs/SOURCES | `-Mode Full` |
| Submodule toolkit | `-WithSubmodule` (нужен git в target) |
| Повторный накат в непустую | `new-project.ps1 … -AllowExisting` — не wipe AGENTS; skip day-0; **перезаписывает** `product-core.mdc` + papercuts hook `.ps1` |

`new-project.ps1` / `.cmd` есть **только в клоне toolkit**, не внутри уже bootstrapped продукта.

## См. также

- Skill: `/bootstrap-project`
- Модель Essential: [`docs/bootstrap-scaffold.md`](../docs/bootstrap-scaffold.md)
- Plugin: [`docs/harness-as-cursor-plugin.md`](../docs/harness-as-cursor-plugin.md)
