# Project agent instructions

This project was bootstrapped with **cursor-project-toolkit** — an AI-agent harness (rules, skills, hooks, docs), not an empty folder.

## Priority

1. Follow project code conventions in this repo.
2. Use `.cursor/rules` and `.cursor/skills` when relevant.
3. Docs are **AI-first** when present under `docs/`.
4. Patterns: `prompting/`, roles in `roles/`, isolation briefs in `subagents/`.

## Autonomous work

- One change/build/fix request should route through `.cursor/skills/autonomous-task` automatically.
- T0/T1: Main direct — research/edit/verify; mechanical multi-file may stay T1; no plan artifact required.
- T2: conditional stages (explore/plan/implement/review/verify) via orchestrator when risk/oracle warrants it — not file count.
- T3: reviewed plan + principal approval before writes + independent review + verification.
- T4, destructive actions, external writes, secrets, deploy/publish/push: stop with a compact Human Gate Packet.
- Never claim done without acceptance criteria + deterministic checks + no open blocker.

## Papercuts (automatic + manual)

- Failed shell commands may be **auto-logged** by `.cursor/hooks` into `.papercuts.jsonl`.
- Session start may inject phase/doctor summary from `docs/project-state.md` via `scripts/project-doctor.ps1`.
- Cross-PC setup: read `@docs/project-state.md` and invoke `/setup-project-environment` (no silent installs).
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
- Recommended: `/add-plugin cursor-team-kit` for CI/PR workflows.

## Learned User Preferences

- (filled by continual-learning plugin or manually)

## Learned Workspace Facts

- Bootstrapped from cursor-project-toolkit harness
