# Новый проект из toolkit (не голая папка)

## Цель

Стартовать продукт в **настроенной среде для ИИ-агентов**: rules, skills, hooks, papercuts, AI-first docs — а не в пустом каталоге.

## Шаги (человек)

1. Создай папку/репо продукта (или пустой git).
2. Из toolkit:

```powershell
cd C:\Users\katko\Desktop\Programms\cursor-project-toolkit
.\scripts\bootstrap-into-project.ps1 -TargetPath C:\path\to\new-app -Mode Essential
# опционально:
.\scripts\bootstrap-into-project.ps1 -TargetPath C:\path\to\new-app -Mode Essential -WithSubmodule
```

3. Открой `new-app` в Cursor.
4. `/add-plugin cursor-team-kit` (и при желании `continual-learning`).
5. Пиши продукт; failed shell → papercuts сами; остальное — `papercuts add`.
6. Раз в неделю: `papercuts list --format md` → чини harness в **продукте** (и при необходимости апстримь паттерн обратно в toolkit).

## Шаги (агент)

Используй skill **`bootstrap-project`**.

## Что считать успехом

- [ ] В продукте есть `.cursor/hooks.json` и `AGENTS.md`
- [ ] Есть `product-core.mdc` + skill `review-papercuts`
- [ ] **Нет** toolkit-only skills (`ship-toolkit`, `add-source`, …)
- [ ] Есть Essential `prompting/` / `roles/` / `subagents/verifier`
- [ ] `.papercuts.jsonl` появляется после первого fail/add
- [ ] Не нужно вручную «настраивать Cursor с нуля» каждый раз

## См. также

- [`docs/bootstrap-scaffold.md`](../docs/bootstrap-scaffold.md)
- [`docs/harness-as-cursor-plugin.md`](../docs/harness-as-cursor-plugin.md)
