# Cursor Project Toolkit — agent instructions

## Mission

This repo is a **bootstrap scaffold** for AI-agent development environments.

- It collects AI-first docs, rules, skills, hooks, papercuts.
- It is **copied/bootstrapped into new product projects** so work does not start in a bare folder.
- Docs are **AI-first, human-second**.

New product → skill **`bootstrap-project`** / `scripts/bootstrap-into-project.ps1`.  
Details: `docs/bootstrap-scaffold.md`.

## Read first

1. `docs/bootstrap-scaffold.md` — why this repo exists
2. `docs/cursor-official-index.md` — official Cursor map
3. `docs/README.md` — how we write docs
4. `SOURCES.md` — external resources

## Repo layers

| Layer | Path | Use |
|-------|------|-----|
| Main docs | `docs/` | Distilled, actionable |
| Source registry | `SOURCES.md` | Every borrow → ID |
| Archive | `archive/` | Full copies only if needed |
| Live harness | `.cursor/rules|skills|hooks` | Executes in this repo and after bootstrap |
| Bootstrap | `scripts/bootstrap-into-project.ps1`, `templates/` | Seed new projects |

Do **not** load `archive/` unless a doc points there.

## When adding material

1. Next `SRC-NNN` in `SOURCES.md`
2. AI-first distill in `docs/` (`## For agents` first)
3. Update `docs/README.md` index
4. Prefer link over copy; archive only if needed
5. Prefer `/add-source` skill
6. If it should ship to products → ensure Essential bootstrap copies it

## Style

- Short imperatives, tables, checklists
- Project skills: **`description` in Russian**; `name` Latin kebab — `docs/skills-russian-descriptions.md`

## Papercuts (auto + manual)

**Automatic (hooks):**
- `afterShellExecution` — failed shell → auto cut (rate limit + dedupe)
- `sessionStart` — set context / HOME reminder
- `stop` — at most once/day nudge if open cuts exist

**Manual** (docs lies, missing tool, wrong cwd — hook may miss):

```powershell
$env:HOME = $env:USERPROFILE
papercuts add "<what you hit and what would have prevented it>" --tag <area>
```

Fallback: `scripts/papercuts.ps1 add "..." -Tag <area>`.  
Review: `/review-papercuts`. Details: `docs/papercuts.md`.

## Git / ship

- Branch + small PRs for non-trivial work
- No force-push `main`; no secrets
- Prefer `/ship-toolkit` when user asks to commit/push

## Learned User Preferences

- Documentation priority: AI agents first, humans second
- Two-layer knowledge: `docs/` + `archive/`; registry in `SOURCES.md`
- Project skill `description` fields in Russian for the `/` menu
- Repo is a **scaffold bootstrapped into new projects**, not only a reading library

## Learned Workspace Facts

- Remote: `https://github.com/MihaRooll/cursor-project-toolkit.git`
- Official Cursor distillations: `docs/cursor-*.md` (SRC-004…009)
- Windows: `$env:HOME = $env:USERPROFILE` for papercuts; prefer git repo cwd or `--file`
- Hooks live in `.cursor/hooks.json` (PowerShell)
