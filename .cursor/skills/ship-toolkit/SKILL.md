---
name: ship-toolkit
description: Закоммитить и запушить изменения toolkit (GitHub flow, опционально PR). Когда просят commit, push, PR, «зашей», отправить на GitHub.
---

# Зашить в GitHub (ship-toolkit)

## Когда использовать

- Просят commit / push / PR / «зашей» / ship
- Пачка правок docs/harness готова к публикации

## Предусловия

- Коммит только если пользователь явно попросил (или ясно сказал «зашей»).
- Не трогать git config; не force-push в `main`; не skip hooks без просьбы.
- Не коммитить `.env`, credentials, секреты.

## Шаги

1. Parallel inspect:
   - `git status`
   - `git diff` (staged + unstaged)
   - `git log -5 --oneline` (message style)
2. If on `main` and change is non-trivial: `git switch -c <descriptive-branch>`.
3. Stage relevant files only (not secrets, not unrelated junk).
4. Commit with HEREDOC message focused on **why** (1–2 sentences).
5. Push: prefer PowerShell/`gh` auth on Windows if WSL git 403s:

```bash
powershell.exe -NoProfile -Command "cd 'C:\Users\katko\Desktop\Program\cursor-project-toolkit'; git push -u origin HEAD"
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
