# Blume: AI-ready markdown docs (выжимка)

> Формат: **AI-first → human-second**. Источник: [SRC-003](../SOURCES.md) — [useblume.dev](https://useblume.dev/).

## For agents

**Когда читать:** выбор/дизайн docs-сайта для toolkit или продукта; нужно отдать Markdown и людям, и моделям (Cursor, MCP, llms.txt).

**Применяй идеи (даже без Blume):**
- **Source of truth = Markdown в репо** (`docs/`), не CMS-first
- Каждый URL docs должен иметь **сырой `.md`** (или эквивалент) для LLM
- Публикуй **`llms.txt`** (индекс корпуса для агентов)
- Если docs публичные — рассмотри **MCP server** (search/read), чтобы агенты не скрейпили HTML
- Навигация/поиск/changelog из файлов; конфиг — только когда нужно
- OpenAPI/AsyncAPI → интерактивный reference, если есть API

**Не делай:**
- Не подменяй нашу AI-first выжимку «красивым сайтом» без содержания
- Не тащи Blume в этот репо, пока явно не решили шипить public docs site
- Секреты/ключи AI для in-page assistant — только env, не в git

**Вердикт для toolkit:** принцип «built for humans and models» совпадает с нашей политикой. Стек Blume — опциональный **renderer** поверх `docs/`, не замена `docs/` + `SOURCES.md` + `archive/`.

---

## Что такое Blume (факты)

| Свойство | Деталь |
|----------|--------|
| Суть | Markdown-first docs site, zero-config, OSS (MIT), Astro + Vite |
| Старт | `npx blume init` |
| Контент | Папка Markdown; можно смешивать filesystem + remote GitHub + CMS (Sanity/Notion/custom) |
| AI-слой | In-page Ask AI, MCP server, `llms.txt`, raw Markdown по URL (`.md`), copy/open in chat |
| Прочее | Search, SEO/OG, i18n (36 locales), changelog (MD или GitHub Releases), OpenAPI/AsyncAPI (Scalar), 30+ MDX-компонентов |

### AI-фичи (зачем нам)

| Фича | Польза агенту |
|------|----------------|
| `llms.txt` | Машинный индекс всего корпуса |
| MCP (`search_docs`, `get_page`, …) | Чтение docs без scraping |
| `page.md` на каждом URL | Сырой источник для LLM |
| Ask AI in-page | Для людей; нам вторично |

### Когда имеет смысл внедрять

| Да | Нет / позже |
|----|-------------|
| Публикуем toolkit как сайт | Пока только git + Cursor |
| Нужен MCP/llms.txt из коробки | Хватает `docs/*.md` в репо |
| OpenAPI + changelog timeline | Нет публичного API/релизов |

---

## Связь со слоями toolkit

```
docs/  (основное, AI-first)  ──►  опционально Blume site
SOURCES.md / archive/        ──►  не рендерятся как «продуктовые» docs по умолчанию
```

Blume = способ **отдать** уже написанный Markdown наружу (люди + модели). Авторство и стандарт выжимок остаются в [`docs/README.md`](README.md).

---

## Источник

- https://useblume.dev/
- Реестр: [SRC-003](../SOURCES.md)
