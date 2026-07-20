# In-session security review: Claude vs Cursor

> **AI-first.** Claude: [SRC-022](../SOURCES.md) — [security-guidance](https://code.claude.com/docs/en/security-guidance). Cursor: [Bugbot](https://cursor.com/docs/bugbot) · [Hooks](https://cursor.com/docs/hooks) · [thermos](cursor-official-plugins.md) · partners (Semgrep/Corridor/Snyk).

## For agents

**Когда читать:** пользователь хочет «как Claude security-guidance, но в Cursor»; выбор auto vs on-demand security; дизайн hooks.

**Вердикт:** у Cursor **нет** official drop-in plugin с тремя авто-слоями Claude (`per-edit` + `end-of-turn` + `commit`). Ближайший стек:

| Цель | Cursor (что ставить / делать) |
|------|-------------------------------|
| Security pass перед push | `/review-security` или `/review` (Bugbot Security Review; Cursor 3.7+) |
| Bugs + sync с PR Bugbot | `/review-bugbot` → тот же patch ID на GitHub/GitLab |
| Жёсткий branch security/quality | `/add-plugin thermos` |
| Auto на каждый edit (как Claude layer 1) | Hooks `afterFileEdit` + pattern script **или** partner [Semgrep](https://semgrep.dev/blog/2025/cursor-hooks-mcp-server) / [Corridor](https://corridor.dev/blog/corridor-cursor-hooks/) |
| Auto end-of-turn / commit (как Claude 2–3) | DIY: `stop` + `afterShellExecution` (filter `git commit`/`push`) **или** partner; нет first-party bundle |
| Threat model текста | Project rule / `AGENTS.md` / skill (аналог `.claude/claude-security-guidance.md`) |
| Block dangerous tools | `beforeShellExecution` / `beforeMCPExecution` + `failClosed: true`; partner [Snyk Evo Agent Guard](https://snyk.io/blog/evo-agent-guard-cursor-integration/) |

**Не делай:** обещать «поставь один Cursor plugin = security-guidance»; путать Bugbot (on-demand/PR) с always-on Claude hooks; тащить Claude plugin в Essential toolkit.

---

## Что делает Claude `security-guidance`

Install: `/plugin install security-guidance@claude-plugins-official` ([docs](https://code.claude.com/docs/en/security-guidance)).

| Слой | Когда | Как |
|------|-------|-----|
| Pattern | Каждый edit | String match (`eval`, `pickle`, `innerHTML`, `.github/workflows/…`); 0 model cost |
| Turn review | End of turn | Background model на git diff хода; findings → re-prompt writer |
| Commit/push | Claude делает `git commit`/`push` | Agentic review + surrounding code |
| Extend | Project files | `.claude/claude-security-guidance.md` + `security-patterns.yaml` |

Не блокирует write/commit — defense in depth. Отдельный reviewer context (не self-grade).

---

## Cursor: слои vs слои

| Claude слой | Cursor ближайшее | Auto? |
|-------------|------------------|-------|
| Per-edit patterns | `afterFileEdit` hook + regex/Semgrep | Только если настроил |
| End-of-turn model review | Нет first-party; DIY `stop` hook → review script/agent | DIY / partner |
| Commit/push review | Bugbot on PR; локально `/review*` before push; DIY shell hook | PR auto; local manual |
| Project threat model | `.cursor/rules/*.mdc` или AGENTS section | Always-on text |
| `/security-review` (Claude on-demand) | `/review-security` / `/review` | On demand |

---

## Рекомендуемый Cursor stack (практика)

### P0 — без кастомных hooks (большинству)

```text
1. /add-plugin thermos          # deep branch when it matters
2. Перед push на чувствительный diff:
   /review-security             # или /review → выбрать Security
   /review-bugbot               # bugs; dedupe на PR
3. Bugbot на GitHub/GitLab PR   # https://cursor.com/docs/bugbot
4. CI: Semgrep / CodeQL / deps  # то, что plugin не заменяет
```

### P1 — ближе к Claude always-on

1. Читай [Hooks](https://cursor.com/docs/hooks): `afterFileEdit`, `stop`, `afterShellExecution`
2. Pattern layer: маленький script (как Claude patterns) → append warning в лог / agent message если API позволяет
3. Partner shortcut: **Semgrep** или **Corridor** hooks (официально в [Partner Integrations](https://cursor.com/docs/hooks#partner-integrations))
4. Agent-action guard (injection / dangerous tools): **Snyk Evo Agent Guard**
5. Threat model: короткий always-on rule (не 2k-line checklist)

### P2 — уже в toolkit harness

| У нас | Не security-guidance |
|-------|----------------------|
| `afterShellExecution` → papercuts | Friction log, не vuln scan |
| `roles/reviewer` | Manual rubric |
| Addy `security-and-hardening` skill | On-demand process, не hook |

Можно compound: product rule «перед ship `/review-security`» + optional Semgrep hook — не дублировать Claude plugin в Essential.

---

## DIY hook skeleton (идея, не ship в Essential)

```json
{
  "version": 1,
  "hooks": {
    "afterFileEdit": [{ "command": ".cursor/hooks/security-patterns.ps1" }],
    "stop": [{ "command": ".cursor/hooks/security-turn-nudge.ps1" }]
  }
}
```

- Patterns: детерминированный scan diff/file (как Claude layer 1)
- `stop`: nudge «run `/review-security`» если dirty tree + sensitive paths — **дешевле** полного model review каждый turn
- Полный turn/commit LLM review из hook = своя стоимость/сложность; Claude уже упаковал это — Cursor пока нет

Source inspiration: [anthropics/claude-plugins-official …/security-guidance](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/security-guidance) (hooks example).

---

## Связь с toolkit

| Тема | Файл |
|------|------|
| Plugins map | [cursor-official-plugins.md](cursor-official-plugins.md) |
| Team Kit review/ship | [cursor-team-kit.md](cursor-team-kit.md) |
| Addy security skill | [addyosmani-agent-skills.md](addyosmani-agent-skills.md) |
| Our hooks (papercuts) | [papercuts.md](papercuts.md) |
| Clean Code / review | [clean-code-javascript.md](clean-code-javascript.md) · [roles/reviewer.md](../roles/reviewer.md) |

---

## Источники

- https://code.claude.com/docs/en/security-guidance — [SRC-022](../SOURCES.md)
- https://cursor.com/docs/bugbot
- https://cursor.com/docs/hooks · [hooks partners blog](https://cursor.com/blog/hooks-partners)
- https://cursor.com/blog/bugbot-updates-june-2026 (`/review`, `/review-security`)
