---
name: distill-doc
description: Сделать или переписать документ AI-first для toolkit. Когда текст слишком «для людей», нет блока For agents, или просят выжимку для агента.
---

# Выжимка документа (distill-doc)

## Когда использовать

- Заметка в стиле эссе / воды
- Нужен канонический файл `docs/*.md`
- Фразы: «сделай AI-first», «выжми для агента»

## Steps

1. Identify one topic → one filename (`docs/<topic-slug>.md`).
2. Structure:

```markdown
# <Title>

> Формат: **AI-first → human-second**. Источник: [SRC-NNN](../SOURCES.md) — <url>

## For agents

**Когда читать:** …
**Применяй:** …
**Не делай:** …

---

## <Facts / tables>

## Чеклист (optional)

## Источник
```

3. Move narrative to 1–2 lines or drop (link to source).
4. Prefer tables over paragraphs.
5. If source is new → run `add-source` flow (or ensure SRC exists).
6. Update `docs/README.md` index.
7. Если создаёшь/правишь skill — `description` **на русском** (`docs/skills-russian-descriptions.md`).

## Anti-patterns

- Pasting full blog HTML/markdown
- Missing `## For agents`
- Duplicate of another `docs/` file — merge or cross-link instead
- Английский `description` у project skills этого репо
