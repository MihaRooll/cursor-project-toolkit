# Matt Pocock Skills — for real engineers

> **AI-first.** Источник: [SRC-020](../SOURCES.md) — [mattpocock/skills](https://github.com/mattpocock/skills) (MIT) · [skills.sh](https://skills.sh). Small, composable agent skills — не vibe coding, не тяжёлый process-owner (GSD/BMAD/Spec-Kit).

## For agents

**Когда читать:** продукт хочет «engineering skills» Matt’а; grill/align перед кодом; shared language / CONTEXT.md; выбор между packs (Matt vs Addy vs UI).

**Применяй:**
1. В **продуктовом** репо: `npx skills@latest add mattpocock/skills` → выбери skills + агентов; **обязательно** включи `setup-matt-pocock-skills`
2. Один раз на репо: `/setup-matt-pocock-skills` (tracker: GitHub/Linear/local; triage labels; куда класть docs)
3. Перед нетривиальной сменой: `/grill-me` или `/grill-with-docs` (align + domain language + ADRs)
4. Router: `/ask-matt` — какой flow подходит
5. User-invoked оркестрирует; model-invoked = discipline. User-invoked **не** вызывает другой user-invoked

**Не делай:**
- Vendoring всего репо в toolkit Essential bootstrap
- Ставить pack + [Addy agent-skills](addyosmani-agent-skills.md) целиком разом без нужды (дубли grill/TDD/review)
- Путать с [UI Skills](ui-skills.md) или [prompts.chat REJECT](prompts-chat-verdict.md)
- Пропускать setup — triage/to-tickets сломаются без tracker config

**Вердикт:** **USE on demand in product apps**. Философия ближе к нашему lean harness (composable, control у человека), чем к «владеющему процессом» фреймворку. Toolkit = карта + recipe.

---

## Install

```powershell
npx skills@latest add mattpocock/skills
# в агенте: выбрать skills; обязательно setup-matt-pocock-skills
# затем:
# /setup-matt-pocock-skills
```

| Путь | Философия |
|------|-----------|
| **skills.sh** | Копия в проект — можно хакать / форкать |
| **Claude Code plugin** | Managed bundle, обновляется с автором; не edit locally |

```text
/plugin marketplace add mattpocock/skills
/plugin install mattpocock-skills@mattpocock
```

Cursor / Codex / др.: через skills.sh (Agent Skills standard). После install — new chat.

---

## Failure modes → skills

| # | Проблема | Fix |
|---|----------|-----|
| 1 | Agent не то сделал (misalignment) | `/grill-me`, `/grill-with-docs` |
| 2 | Verbose / нет domain jargon | Shared language → `CONTEXT.md` (+ ADRs) via grill-with-docs / domain-modeling |
| 3 | Код не работает | Feedback loops: `/tdd`, `/diagnosing-bugs` |
| 4 | Ball of mud | Design daily: `/to-spec` (какие модули), `/improve-codebase-architecture` |

Позиция upstream: тяжёлые process frameworks отнимают контроль; эти skills — маленькие и адаптируемые.

---

## Skill map (reference)

### Engineering — user-invoked

| Skill | Зачем |
|-------|--------|
| `ask-matt` | Router по user-invoked |
| `setup-matt-pocock-skills` | Once per repo |
| `grill-with-docs` | Grill + domain model + CONTEXT/ADRs |
| `to-spec` | Conversation → spec (без interview) |
| `to-tickets` | Tracer-bullet tickets + blockers |
| `implement` | Spec/tickets → TDD seams → code-review → commit |
| `triage` | Issue state machine + labels |
| `wayfinder` | Multi-session investigation map |
| `improve-codebase-architecture` | Deepening opportunities → HTML report → grill |

### Engineering — model-invoked

| Skill | Зачем |
|-------|--------|
| `tdd` | Red-green-refactor slices |
| `diagnosing-bugs` | Reproduce → minimise → hypothesise → instrument → fix → regression |
| `code-review` | Parallel: Standards vs Spec axes |
| `codebase-design` | Deep modules vocabulary |
| `domain-modeling` | Glossary / edge cases → CONTEXT |
| `prototype` | Throwaway to answer design Q |
| `research` | Cited findings from primary sources |
| `resolving-merge-conflicts` | Hunk-by-hunk by intent; never `--abort` |

### Productivity

| Skill | Тип | Зачем |
|-------|-----|--------|
| `grill-me` | user | Relentless interview (non-code ok) |
| `handoff` | user | Compact chat → handoff doc |
| `teach` | user | Multi-session teaching workspace |
| `writing-great-skills` | user | How to author predictable skills |
| `grilling` | model | Loop behind grill-* |

---

## Рекомендуемый starter set

| Skill | Когда |
|-------|--------|
| `setup-matt-pocock-skills` | Always first |
| `ask-matt` | «Что запустить?» |
| `grill-with-docs` | Любая нетривиальная смена |
| `to-tickets` + `implement` | После align |
| `tdd` | Behavior changes |
| `code-review` | Перед commit/PR |
| `improve-codebase-architecture` | Раз в несколько дней / entropy |

---

## Связь с toolkit

| Тема | Файл |
|------|------|
| Addy lifecycle pack (другой) | [addyosmani-agent-skills.md](addyosmani-agent-skills.md) |
| UI design skills | [ui-skills.md](ui-skills.md) |
| Interview-me vibe (Addy) | похож на grill; не дублировать оба always-on |
| Lean / YAGNI | [ponytail.md](ponytail.md) |
| Handoff / loops | [claude-code-loops.md](claude-code-loops.md) · [prompting/agent-loops.md](../prompting/agent-loops.md) |
| Our continue handoff | [project-workflow/continue-chat-prompt.md](../project-workflow/continue-chat-prompt.md) |
| File-based long-term memory (другой слой) | [reme-agent-memory.md](reme-agent-memory.md) |
| Writing skills (RU desc) | [skills-russian-descriptions.md](skills-russian-descriptions.md) |
| Essential harness | [bootstrap-scaffold.md](bootstrap-scaffold.md) — не тащить Matt pack default |

---

## Источник

- https://github.com/mattpocock/skills
- https://skills.sh
- [SRC-020](../SOURCES.md)
