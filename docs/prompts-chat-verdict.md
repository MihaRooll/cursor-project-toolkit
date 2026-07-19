# prompts.chat — вердикт для toolkit

> **AI-first.** Источник: [SRC-010](../SOURCES.md) — [prompts.chat/prompts](https://prompts.chat/prompts).

## For agents

**Когда читать:** пользователь предлагает «скачать все промпты с prompts.chat / Awesome ChatGPT Prompts».

**Применяй:**
- **Не** bulk-ingest (~2000+ community prompts) в `docs/`, `prompting/` или `archive/`
- Не подключать MCP/датасет prompts.chat как default-контекст агента
- Если пользователь ткнул в **конкретный** промпт с явной ценностью → точечно: `add-source` / выжимка паттерна (не копипаст «Act as…» целиком)
- Для разработки агентов в Cursor приоритет: official Cursor docs/plugins + наши skills/rules, не community dump

**Не делай:** зеркалить каталог «на всякий случай»; считать CC0 = «надо всё забрать».

**Вердикт:** подозрение верное — **много шума**. Платформа ок как витрина/поиск, плоха как корпус для нашего toolkit.

---

## Почему шум (наблюдения со снимка каталога)

| Сигнал | Пример |
|--------|--------|
| Одноразовые задания | «video with my photo as a hero», «design shirt», homework physiology |
| Сырые ТЗ проектов | Admin portal на Apps Script, glassmorphic About Me |
| Вода / generic | «General Assistant System Prompt» без уникального harness |
| Нулевой engagement | многие карточки с `0` votes |
| Tag soup | yoga, dating, comedy рядом с CI/CD — нет фокуса на agent engineering |
| Масштаб | ~2041 prompts — curation cost >> польза |

Даже относительно «нормальные» (LinkedIn About, character questionnaire) — **не наш домен** (маркетинг/креатив), слабо стыкуются с mission toolkit.

---

## Что платформа даёт (честно)

- Open / CC0, поиск, теги, иногда MCP/API
- Наследник Awesome ChatGPT Prompts — исторически большой corpus
- Удобно **люди вручную** ищут идею

Это не делает corpus пригодным для AI-first `docs/` без жёсткого фильтра.

---

## Политика ingest из community prompt libs

Брать только если **все** пункты true:

1. Повторяемый паттерн (не one-off ТЗ)
2. Релевантно agent/dev workflow (plan, review, TDD, context, roles)
3. Можно сжать в таблицу/чеклист без «Act as a …» эссе
4. Есть сигнал качества (votes / known author / проверено нами)

Иначе — skip.

---

## Источник

https://prompts.chat/prompts · [SRC-010](../SOURCES.md)
