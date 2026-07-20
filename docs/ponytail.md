# Ponytail — lazy senior agent mode

> **AI-first.** Источник: [SRC-017](../SOURCES.md) — [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) (MIT).

## For agents

**Когда читать:** over-engineering; «поставь либу на date picker»; review diff на лишнее; пользователь просит ponytail / YAGNI hard.

**Применяй:**
1. Прочитай задачу + код → **потом** ladder (не вместо чтения)
2. Остановись на первом валидном rung
3. Не режь: trust-boundary validation, data-loss handling, security, a11y, explicit requests
4. Non-trivial logic → ONE runnable check (маленький test/assert); trivial one-liner — без теста
5. Углы с потолком → комментарий `ponytail: <ceiling> → <upgrade>`

**Не делай:** golf ради golf; «smallest wrong place»; новый dependency «на всякий»; абстракции без просьбы.

**Вердикт:** **USE in product Cursor** (copy rule). Не тащить весь multi-host plugin в Essential toolkit bootstrap — opt-in per product. Уже стоит в TG_BOT_PRO.

---

## Ladder (перед кодом)

| # | Вопрос | Действие |
|---|--------|----------|
| 1 | Нужно ли вообще? | YAGNI → skip |
| 2 | Уже есть в репо? | reuse |
| 3 | Stdlib? | use |
| 4 | Native platform? | use (`<input type="date">`) |
| 5 | Уже установленная dep? | use |
| 6 | Одна строка? | one line |
| 7 | Иначе | minimum that works |

Bugfix = root cause once (shared function), не patch только ticket path.

---

## Cursor install

Instruction-only (без `/ponytail` commands плагина):

```powershell
# из clone ponytail или raw:
# copy .cursor/rules/ponytail.mdc → <product>/.cursor/rules/ponytail.mdc
```

Или вставь содержимое [AGENTS.md](https://github.com/DietrichGebert/ponytail/blob/main/AGENTS.md) / `.cursor/rules/ponytail.mdc` в проект.

Официально: Claude/Codex — marketplace plugin; Cursor — **copy rules file**.

Уровни (`lite`/`full`/`ultra`/`off`) — в plugin hosts; в Cursor обычно always-on full ruleset.

Commands (plugin hosts): `/ponytail-review`, `/ponytail-audit`, `/ponytail-debt`, …
В Cursor аналог: `@roles/reviewer` + промпт «delete-list for over-engineering» или skill позже.

---

## Benchmark (честные agentic цифры)

На Claude Code vs no-skill, FastAPI+React template, 12 features: ~**−54% LOC**, ~−20% cost, ~−27% time, **100% safe**.
Правило ≠ fewest tokens — necessary code only. Детали: repo `benchmarks/`.

Парытся с [caveman](https://github.com/JuliusBrussee/caveman): caveman = terse prose; ponytail = minimal build.

---

## Связь с toolkit

| Идея | Наш файл |
|------|----------|
| Lean / autonomy | [lean-prompts-autonomy.md](../prompting/lean-prompts-autonomy.md) |
| Constraint-first | [constraint-first.md](../prompting/constraint-first.md) |
| OpenAI lean ladder vibe | [openai-gpt56-model-guidance.md](openai-gpt56-model-guidance.md) |
| Review overbuild | [roles/reviewer.md](../roles/reviewer.md) |
| Consumer example | TG_BOT_PRO `AGENTS.md` + `ponytail.mdc` |

Не добавлять в Essential bootstrap по умолчанию — конфликт с проектами, где нужна «полная» архитектура; ставь явно.

---

## Источник

https://github.com/DietrichGebert/ponytail · [SRC-017](../SOURCES.md)
