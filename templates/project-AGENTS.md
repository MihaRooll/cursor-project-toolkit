# Project agent instructions

This project was bootstrapped with **cursor-project-toolkit** — an AI-agent harness (rules, skills, hooks, docs), not an empty folder.

## Priority

1. Follow project code conventions in this repo.
2. Use `.cursor/rules` and `.cursor/skills` when relevant.
3. Docs are **AI-first** when present under `docs/`.

## Papercuts (automatic + manual)

- Failed shell commands may be **auto-logged** by `.cursor/hooks` into `.papercuts.jsonl`.
- If you hit friction the hook missed (bad docs, wrong cwd, missing tool):

```powershell
$env:HOME = $env:USERPROFILE   # Windows, if needed
papercuts add "<what broke and what would prevent it>" --tag tooling
```

Fallback: `scripts/papercuts.ps1 add "..." -Tag tooling`

Do not stop the user task — log and continue. Review backlog with `/review-papercuts` or `papercuts list --format md`.

## Ship

- Prefer branches + small PRs.
- Do not commit secrets.
- Use project scripts/checks when they exist.

## Learned User Preferences

- (filled by continual-learning plugin or manually)

## Learned Workspace Facts

- Bootstrapped from cursor-project-toolkit harness
