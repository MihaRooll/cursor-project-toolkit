# Addy Osmani Agent Skills — lifecycle pack

> **AI-first.** Источник: [SRC-019](../SOURCES.md) — [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) (MIT). Production-grade engineering skills для AI coding agents: DEFINE → PLAN → BUILD → VERIFY → REVIEW → SHIP.

## For agents

**Когда читать:** нужен зрелый SDLC для агента; пользователь кинул agent-skills / «как у Addy»; выбор skill под фазу работы.

**Применяй:**
1. В **продуктовом** репо: сначала `npx skills add addyosmani/agent-skills --list` → ставь **точечно**, не все 24
2. Cursor: skills → `.cursor/skills/`; короткие политики → `.cursor/rules/*.mdc` — **не** вставляй полный SKILL в rules ([cursor-setup](https://github.com/addyosmani/agent-skills/blob/main/docs/cursor-setup.md))
3. Lifecycle slash (где поддерживается): `/spec` → `/plan` → `/build` → `/test` → `/review` → `/ship` (+ `/webperf`, `/code-simplify`)
4. Meta first: `using-agent-skills` — какой skill подходит к запросу
5. Каждая skill = process + anti-rationalization + verification evidence («seems right» ≠ done)

**Не делай:**
- Bulk-clone всего репо в `cursor-project-toolkit` / Essential bootstrap
- Ставить все 24 skills always-on (шум контекста; конфликт с lean harness)
- Путать с [UI Skills](ui-skills.md) (design polish) или [prompts.chat REJECT](prompts-chat-verdict.md) (community dump)
- Пастить полные skills в always-on rules

**Вердикт:** **USE on demand in product apps**. Toolkit держит карту + install recipe. Парится с Team Kit / нашим harness, не заменяет их.

---

## Install (Cursor-first)

```powershell
# browse
npx skills add addyosmani/agent-skills --list

# selective (examples)
npx skills add addyosmani/agent-skills --skill using-agent-skills
npx skills add addyosmani/agent-skills --skill interview-me
npx skills add addyosmani/agent-skills --skill test-driven-development
npx skills add addyosmani/agent-skills --skill code-review-and-quality

# full pack only if user explicitly wants it
npx skills add addyosmani/agent-skills
```

Claude Code marketplace: `/plugin marketplace add addyosmani/agent-skills` → `/plugin install agent-skills@addy-agent-skills`
(SSH fail → HTTPS URL; см. README upstream.)

После install в Cursor — **new chat** / reload skills discovery.

---

## Lifecycle map

```text
DEFINE → PLAN → BUILD → VERIFY → REVIEW → SHIP
/spec    /plan  /build  /test    /review  /ship
```

| Фаза | Skills (slug) | Когда |
|------|---------------|--------|
| Meta | `using-agent-skills` | Старт сессии / выбор skill |
| Define | `interview-me`, `idea-refine`, `spec-driven-development` | Ask размыт; нужен PRD до кода |
| Plan | `planning-and-task-breakdown` | Spec → atomic tasks + AC |
| Build | `incremental-implementation`, `test-driven-development`, `context-engineering`, `source-driven-development`, `doubt-driven-development`, `frontend-ui-engineering`, `api-and-interface-design` | Реализация / UI / API / high-stakes doubt |
| Verify | `browser-testing-with-devtools`, `debugging-and-error-recovery` | Доказать / починить |
| Review | `code-review-and-quality`, `code-simplification`, `security-and-hardening`, `performance-optimization` | Перед merge |
| Ship | `git-workflow-and-versioning`, `ci-cd-and-automation`, `deprecation-and-migration`, `documentation-and-adrs`, `observability-and-instrumentation`, `shipping-and-launch` | Deploy / ops |

`/build auto` (upstream): один approve плана → автономный проход задач; всё ещё TDD + commit per task; пауза на failure/risky.

---

## Рекомендуемый starter set (не весь pack)

| Skill | Зачем |
|-------|--------|
| `using-agent-skills` | Router / operating rules |
| `interview-me` | Underspecified asks |
| `spec-driven-development` | Non-trivial feature до кода |
| `planning-and-task-breakdown` | Atomic tasks |
| `incremental-implementation` | Thin vertical slices |
| `test-driven-development` | Behavior changes |
| `code-review-and-quality` | Pre-merge five-axis |
| `security-and-hardening` | Auth / input / secrets |
| `shipping-and-launch` | Prod go-live |

Остальное — по домену (frontend, webperf, observability, deprecation).

---

## Personas (agents/)

| Agent | Роль |
|-------|------|
| `code-reviewer` | Staff-level five-axis review |
| `test-engineer` | Prove-It / coverage |
| `security-auditor` | OWASP / threat |
| `web-performance-auditor` | CWV; `/webperf` |

Orchestration: personas **не** вызывают personas (см. upstream `references/orchestration-patterns.md`).

---

## Anatomy (что копировать в свои skills)

| Блок | Зачем |
|------|--------|
| Frontmatter `name` + `description` | Discovery |
| Process steps | Workflow, не эссе |
| Rationalizations table | «I'll add tests later» → rebuttal |
| Red flags | Когда остановиться |
| Verification | Evidence required |

Progressive disclosure: `SKILL.md` короткий; `references/` по нужде.

---

## Связь с toolkit

| Тема | Файл |
|------|------|
| Наш Essential harness | [bootstrap-scaffold.md](bootstrap-scaffold.md) |
| Cursor Team Kit (CI/ship) | [cursor-team-kit.md](cursor-team-kit.md) |
| Rules vs Skills | [cursor-primitives.md](cursor-primitives.md) |
| UI design skills (другой pack) | [ui-skills.md](ui-skills.md) |
| Matt Pocock composable pack | [mattpocock-skills.md](mattpocock-skills.md) — grill/CONTEXT; не ставить оба packs целиком |
| Lean / YAGNI | [ponytail.md](ponytail.md) |
| Review role | [roles/reviewer.md](../roles/reviewer.md) |
| Loops / handoff | [claude-code-loops.md](claude-code-loops.md) |

Не добавлять pack в Essential bootstrap toolkit — продукт ставит selective.

---

## Источник

- https://github.com/addyosmani/agent-skills
- Cursor setup: https://github.com/addyosmani/agent-skills/blob/main/docs/cursor-setup.md
- [SRC-019](../SOURCES.md)
