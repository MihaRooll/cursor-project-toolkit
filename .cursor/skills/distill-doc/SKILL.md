---
name: distill-doc
description: Rewrite or create an AI-first documentation file for this toolkit. Use when docs are too narrative, need For agents section, or user asks to make docs agent-ready.
---

# Distill doc

## When to use

- Existing note is human-essay style
- New topic needs a canonical `docs/*.md`
- User asks to "сделай AI-first" / "выжми для агента"

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

## Anti-patterns

- Pasting full blog HTML/markdown
- Missing `## For agents`
- Duplicate of another `docs/` file — merge or cross-link instead
