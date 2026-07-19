# Dynamic context discovery (выжимка)

> **AI-first.** Источник: [SRC-007](../SOURCES.md) — [Dynamic context discovery](https://cursor.com/blog/dynamic-context-discovery).

## For agents

**Когда читать:** дизайн docs/skills/MCP для toolkit; борьба с раздутым контекстом.

**Применяй при авторстве toolkit:**
- **Static** = короткий индекс (имена, description, llms-style TOC)
- **Dynamic** = тело файла агент читает сам, когда нужно
- Skills: `description` в индексе (в этом репо — **на русском**), детали в `SKILL.md` / `references/` — см. [skills-russian-descriptions.md](skills-russian-descriptions.md)
- MCP: не рассчитывать что все tool descriptions всегда в промпте — учи навык «сначала list/read tools»
- Длинные выводы команд → писать в файл, читать через `tail`/grep, не пихать целиком в чат
- Наша схема `docs/` + `SOURCES.md` + `archive/` = тот же паттерн (выжимка vs сырьё)

**Не делай:** пихать весь archive и все MCP tools в always-on rules.

---

## Тезис

Меньше деталей upfront → агент сам подтягивает нужное → меньше токенов, меньше противоречий, выше качество.

Cursor-паттерны:

| # | Паттерн | Смысл |
|---|---------|--------|
| 1 | Long tool output → files | Нет truncation-потери; agent читает выборочно |
| 2 | Chat history as files after summarize | Recover детали из history file |
| 3 | Agent Skills | Name/description static; body on demand |
| 4 | MCP tools → folder sync | ~46.9% меньше токенов в A/B при вызове MCP |
| 5 | Terminal sessions as files | «Why did command fail?» без copy-paste |

Примитив: **files** как интерфейс к контексту (проще будущих абстракций).

---

## Для нашего репо

| Слой | Static index | Dynamic body |
|------|--------------|--------------|
| docs | `docs/README.md`, `SOURCES.md` | полный `docs/*.md` |
| archive | путь в SOURCES | файлы только по нужде |
| skills (будущие) | description | SKILL.md + references |

---

## Источник

https://cursor.com/blog/dynamic-context-discovery · [SRC-007](../SOURCES.md)
