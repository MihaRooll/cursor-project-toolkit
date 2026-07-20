# Harness consumers — живые продукты

> **AI-first.** Реестр проектов, куда накатан Essential harness. Нужен для loop: bootstrap → papercuts → compound в toolkit.

## For agents

**Когда читать:** перед правкой Essential bootstrap; вопрос «где уже стоит harness»; triage papercuts из продуктов.

**Применяй:**
- Новый consumer → строка в таблице + bootstrap Essential (не Full)
- Friction из продукта → cut в продукте; повторяющееся → fix в toolkit + resolve
- Не затирай чужой `AGENTS.md` / чужие hooks без merge

**Не делай:** коммитить секреты из product repos в toolkit; считать smoke-папку consumer’ом.

---

## Consumers

| Проект | Path | Bootstrap | Notes |
|--------|------|-----------|-------|
| TG_BOT_PRO | `C:\Users\katko\Desktop\Programms\TG_BOT_PRO` | Essential 2026-07-19 | Свой AGENTS ([ponytail](ponytail.md) SRC-017); snippet appended; hooks toolkit |
| inkavrio_ru | `C:\Users\katko\Desktop\Programms\inkavrio_ru` | Essential 2026-07-19 | Свой `.cursor` + hooks; papercuts events **merged**; snippet appended |

Smoke-only (не consumer): `_toolkit-smoke-test`.

---

## Feedback уже compound’нут

| Cut theme | Fix in toolkit |
|-----------|----------------|
| Existing AGENTS skipped → агент не знает papercuts | `Ensure-AgentsHarnessSnippet` + `templates/project-AGENTS-harness-snippet.md` |
| Existing hooks.json skipped → нет auto-papercuts | `Merge-PapercutsHooks` (добавляет events, не стирает чужие) |
| Нужен installable surface | `plugin/cursor-project-harness` + `scripts/install-harness-plugin.ps1` |

---

## Как добавить consumer

```powershell
cd C:\Users\katko\Desktop\Programms\cursor-project-toolkit
.\scripts\bootstrap-into-project.ps1 -TargetPath C:\path\to\app -Mode Essential
# в продукте:
.\scripts\papercuts.ps1 add "first friction…" -Tag bootstrap
```

Обнови эту таблицу.
