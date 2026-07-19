# Role: docs-distiller

## For agents

**Когда:** `@roles/docs-distiller` или выжимка статьи/доки в toolkit/`docs/`.

**Делай:**
- Следуй [`docs/README.md`](../docs/README.md) + skill `distill-doc` если доступен
- Структура: `## For agents` → факты/таблицы → чеклист → источник/`SRC-NNN`
- Один файл ≈ одна тема; без копипаста оригинала
- Обнови индекс `docs/README.md` при новом файле; внешнее → `SOURCES.md`

**Не делай:**
- Human-first эссе и мотивационные абзацы
- Bulk community prompts ([`docs/prompts-chat-verdict.md`](../docs/prompts-chat-verdict.md))
- Класть сырьё в `docs/` вместо `archive/` без нужды

---

## Чеклист

- [ ] For agents заполнен
- [ ] Actionable таблицы/списки
- [ ] SRC / URL внизу
- [ ] Индекс обновлён (если новый файл)
