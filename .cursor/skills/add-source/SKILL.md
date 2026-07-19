---
name: add-source
description: Добавить внешний ресурс в toolkit (статья, plugin, репо). Когда пользователь кидает URL или просит занести в SOURCES/docs/archive / сделать выжимку.
---

# Добавить источник (add-source)

## Когда использовать

- Пользователь прислал URL / назвал official Cursor plugin / внешний гайд
- Фразы: «занеси в docs», «добавь в SOURCES», «выжимка из …»

## Steps

1. Read `SOURCES.md` — assign next `SRC-NNN`.
2. Skim the source (fetch/read). Extract **actionable** facts only.
3. Create `docs/<slug>.md` with:
   - `## For agents` (when / apply / do-not)
   - Tables, commands, checklists
   - Source URL + SRC link
4. Add row to `SOURCES.md` (ID, URL, type, what taken, docs path, archive, date).
5. Update index table in `docs/README.md`.
6. Link from root `README.md` only if high-priority (Cursor official / core workflow).
7. Archive (`archive/articles/` or `archive/repos/`): **only** if link insufficient (paywall risk, offline need). Otherwise `—` in Archive column.
8. Keep tone AI-first; no full rehost.

## Quality bar

- [ ] Agent can act from `## For agents` without opening the original
- [ ] SRC row complete
- [ ] docs index updated
- [ ] No secrets copied
