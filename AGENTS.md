# Cursor Project Toolkit — agent instructions

## Mission

Collect best practices for AI-assisted development into a synergistic toolkit. Docs are **AI-first, human-second**.

## Read first

1. `docs/cursor-official-index.md` — official Cursor map
2. `docs/README.md` — how we write docs
3. `SOURCES.md` — every external resource we used

## Repo layers

| Layer | Path | Use |
|-------|------|-----|
| Main docs | `docs/` | Distilled, actionable — default context |
| Source registry | `SOURCES.md` | Every borrow gets an ID |
| Archive | `archive/` | Full copies only when needed |
| Live harness | `.cursor/rules/`, `.cursor/skills/` | What agents execute here |

Do **not** load `archive/` unless a doc explicitly points there or details are missing from `docs/`.

## When adding material

1. Assign next `SRC-NNN` in `SOURCES.md`
2. Write AI-first distill in `docs/` (`## For agents` first)
3. Update `docs/README.md` index
4. Prefer link over copying; archive only if link is not enough
5. Prefer `/add-source` skill

## Style

- Short imperatives, tables, checklists
- No fluff; no full rehost of originals
- Point to canonical files instead of pasting large blocks
- Russian OK for product docs in this repo; keep skill/rule machine text clear and structured

## Git / ship

- Feature work on a branch; PR preferred for non-trivial changes
- Do not force-push `main`; do not commit secrets
- Small PRs; descriptive branch names (`add-agents-md`, `docs-cursor-index`)
- Prefer `/ship-toolkit` skill for commit/PR flow

## Learned User Preferences

- Documentation priority: AI agents first, humans second
- Two-layer knowledge: main `docs/` + side `archive/`; registry in `SOURCES.md`

## Learned Workspace Facts

- Remote: `https://github.com/MihaRooll/cursor-project-toolkit.git`
- Official Cursor distillations live under `docs/cursor-*.md` (SRC-004…009)
