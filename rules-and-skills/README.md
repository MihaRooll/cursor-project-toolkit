# rules-and-skills/

Каталог идей и зеркало живого harness.

**Исполняемые** rules/skills лежат в:

- `.cursor/rules/` — project rules
- `.cursor/skills/` — `add-source`, `distill-doc`, `ship-toolkit`, `review-papercuts`, `bootstrap-project`
- `.cursor/hooks.json` — авто-papercuts на failed shell

Сюда кладём дополнительные шаблоны и заметки; не дублируй тело skill без нужды — правь canonical в `.cursor/skills/`.

## Стандарт skills

| Поле | Язык |
|------|------|
| `name` / папка | латиница kebab-case |
| `description` (меню `/`) | **русский** |
| тело `SKILL.md` | русский |

Полностью: [`docs/skills-russian-descriptions.md`](../docs/skills-russian-descriptions.md) · примитивы: [`docs/cursor-primitives.md`](../docs/cursor-primitives.md).
