# Harness как Cursor plugin — решение и путь

> **AI-first.** Когда упаковывать toolkit в installable plugin vs оставаться bootstrap-copy.

## For agents

**Когда читать:** просят «сделай plugin»; сравнивают bootstrap vs marketplace; планируют team distribute.

**Вердикт сейчас:** **не паковать в plugin в этом PR.** Остаёмся на `bootstrap-into-project.ps1` (Essential/Full). Plugin — следующий этап, когда harness стабилен и есть 2+ продукта-потребителя.

**Применяй:**
- Продуктам → Essential bootstrap (copy)
- Обновления библиотеки → опциональный `git submodule` (`-WithSubmodule`) или re-run bootstrap `-Force` выборочно
- Когда созреем → `/add-plugin create-plugin` + scaffold по чеклисту ниже

**Не делай:** форкать весь `cursor-team-kit` в этот репо; дублировать marketplace plugins.

---

## Copy vs Plugin vs Submodule

| Модель | Плюс | Минус | Когда |
|--------|------|-------|-------|
| Essential copy | Просто, продукт независим | Дрейф от upstream | Default для новых apps |
| Full copy | Вся библиотека docs | Шум, путаница toolkit skills | Meta/docs-heavy fork |
| Submodule `vendor/…` | Одна версия истины | Нужен git submodule discipline | Команда хочет sync с toolkit |
| Cursor plugin | `/add-plugin`, единый бандл | Нужен publish/versioning; hooks/paths Windows-sensitive | 2+ продуктов + стабильный surface |

---

## Когда plugin имеет смысл (критерии)

- [ ] Essential harness прошёл smoke на Windows стабильно
- [ ] Product skills/rules отделены от toolkit-only (уже)
- [ ] ≥2 реальных продукта используют harness
- [ ] Есть версионирование (semver / changelog)
- [ ] Hooks проверены вне этого репо

---

## Scaffold checklist (будущее)

1. `/add-plugin create-plugin` (официальный scaffold)
2. `.cursor-plugin/plugin.json`: name, description, skills/rules/hooks paths
3. В plugin класть **product** surface: `product-core`, `review-papercuts`, hooks, papercuts shim docs — **не** `ship-toolkit` / `add-source`
4. Validate plugin layout (create-plugin skill)
5. Private team marketplace или public — решение человека
6. Docs: install = `/add-plugin …` + optional bootstrap для scripts на диске

Официально: [Plugins](https://cursor.com/docs/plugins) · [create-plugin](https://github.com/cursor/plugins/tree/main/create-plugin) · SRC-008/009.

---

## Связанное

- [bootstrap-scaffold.md](bootstrap-scaffold.md)
- [cursor-official-plugins.md](cursor-official-plugins.md)
