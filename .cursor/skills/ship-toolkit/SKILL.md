---
name: ship-toolkit
description: Ship changes to cursor-project-toolkit via GitHub flow (status, branch, commit, push, optional PR). Use when user asks to commit, push, open PR, or ship toolkit updates.
---

# Ship toolkit

## When to use

- User asks to commit / push / PR / "зашей" / ship
- After a batch of docs/harness changes is ready

## Preconditions

- Only commit when the user explicitly asked (or clearly asked to ship).
- Never update git config; never force-push `main`; never skip hooks unless asked.
- Never commit `.env`, credentials, or secrets.

## Steps

1. Parallel inspect:
   - `git status`
   - `git diff` (staged + unstaged)
   - `git log -5 --oneline` (message style)
2. If on `main` and change is non-trivial: `git switch -c <descriptive-branch>`.
3. Stage relevant files only (not secrets, not unrelated junk).
4. Commit with HEREDOC message focused on **why** (1–2 sentences).
5. Push: prefer PowerShell/`gh` auth on Windows if WSL git 403s:

```bash
powershell.exe -NoProfile -Command "cd 'C:\Users\katko\Desktop\Programms\cursor-project-toolkit'; git push -u origin HEAD"
```

6. If user asked for PR:

```bash
gh pr create --title "…" --body "$(cat <<'EOF'
## Summary
- …

## Test plan
- [ ] Docs index links resolve
- [ ] AGENTS.md / rules still coherent
EOF
)"
```

7. Verify with `git status`.

## Message style

- Why over what
- Examples: `Add live Cursor harness so agents follow AI-first docs.` / `Ingest SRC-010 Blume distill into docs.`

## Related

- GitHub flow: `docs/github-for-beginners-essentials.md`
- Team Kit analogs: `review-and-ship`, `new-branch-and-pr`, `deslop` (install plugin for full power)
