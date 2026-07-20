# UI Skills — каталог design-engineering skills

> **AI-first.** Источник: [SRC-016](../SOURCES.md) — [ui-skills.com](https://www.ui-skills.com/) · [github.com/ibelick/ui-skills](https://github.com/ibelick/ui-skills) (MIT).

## For agents

**Когда читать:** UI/frontend polish, motion, a11y, «feels AI-generic», пользователь кинул ui-skills.com.

**Применяй:**
1. В **продуктовом** репо (не в toolkit meta): `npx ui-skills start` — router выберет узкий набор skills
2. Или точечно: `npx ui-skills list --category motion` → `npx ui-skills get <slug>` / `npx ui-skills add <slug>`
3. Audit→plan skills (`improve-ui`, `improve-animations`, `improve`) — **read-only**; implement отдельным агентом/чатом
4. Сверяй с user frontend rules (anti purple-gradient / cream-serif / generic cards) — skill ≠ отмена project taste

**Не делай:**
- Bulk-clone всего registry в `cursor-project-toolkit` / Essential bootstrap
- Ставить 20 UI skills always-on (шум контекста)
- Путать с [prompts.chat REJECT](prompts-chat-verdict.md) — здесь MIT skills + CLI router, но **selective install** всё равно

**Вердикт:** **USE on demand in product apps**. Toolkit держит только эту карту + CLI recipe.

---

## Что это

Каталог **Agent Skills** для design engineering (Cursor / Claude Code / др.). Сайт + CLI роутят по topic/stack/intent к минимальному полезному набору.

| Команда | Зачем |
|---------|--------|
| `npx ui-skills start` | Router: выбери skills под задачу **до** правок |
| `npx ui-skills categories` | Список категорий |
| `npx ui-skills list --category motion` | Skills в категории |
| `npx ui-skills get baseline-ui` | Посмотреть skill |
| `npx ui-skills add <slug>` | Установить в проект (SKILL.md в agent skills path) |

Agent-facing index: https://www.ui-skills.com/llms.txt
Registry: https://www.ui-skills.com/skills/registry.txt

---

## Рекомендуемый starter set (не весь каталог)

| Skill | Когда | Заметка |
|-------|--------|---------|
| `ui-skills-root` | Любой UI ask | Router first |
| `baseline-ui` | Быстрый deslop spacing/type/hierarchy | Fast polish |
| `frontend-design` / `impeccable` / `design-taste-frontend` | Новая поверхность / anti-generic | Pick **one** flagship, not all three |
| `better-ui` | Micro polish (shadows, hover, radius) | Detail pass |
| `improve-ui` | Audit existing surface → plans | Read-only → handoff |
| `improve-animations` | Motion roadmap | Read-only |
| `web-design-guidelines` / a11y (AccessLint) | Compliance / a11y | Before ship |
| `shadcn` | Проект на shadcn/ui | Stack-specific |
| `improve-react` | React Doctor-style audit | Read-only |

Тяжёлые «50 styles / 97 palettes» (`ui-ux-pro-max` и аналоги) — только по явной просьбе; риск generic taste soup.

---

## Workflow в Cursor

```text
User: fix this dialog motion / polish settings page

Agent:
1. Run `npx ui-skills start` (or get/add specific skill)
2. Follow routed skill(s) — smallest set
3. If skill is audit-only → write plan, then implement in same or new chat
4. Verify: browser / visual check (see prompting/verify-loop.md)
```

Skills обычно кладутся в project agent skills dir (см. [skills.sh Cursor](https://www.skills.sh/agent/cursor) / docs skill install path). После add — **new chat** или reload skills discovery.

Не тащить UI Skills в Essential bootstrap toolkit → продукт с UI ставит сам.

---

## Связь с toolkit

| Тема | Файл |
|------|------|
| Anti-generic UI (user rules) | chat / product rules |
| Verify UI | [prompting/verify-loop.md](../prompting/verify-loop.md) |
| Claude prompt starters (UI mockup→code) | [claude-code-prompt-library.md](claude-code-prompt-library.md) |
| GPT-5.6 frontend note | [openai-gpt56-model-guidance.md](openai-gpt56-model-guidance.md) |
| Engineering lifecycle skills (не UI) | [addyosmani-agent-skills.md](addyosmani-agent-skills.md) |

---

## Источник

- https://www.ui-skills.com/
- https://github.com/ibelick/ui-skills
- https://www.ui-skills.com/llms.txt
- [SRC-016](../SOURCES.md)
