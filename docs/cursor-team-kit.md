# Cursor Team Kit (выжимка)

> Формат: **AI-first → human-second**. Источник: [SRC-004](../SOURCES.md) — [Marketplace](https://cursor.com/marketplace/cursor/cursor-team-kit) · [Source](https://github.com/cursor/plugins/tree/main/cursor-team-kit).

## For agents

**Когда читать:** выбор skill/субагента под CI, PR, ship, UI/CLI verify, cleanup, weekly summary; проектирование наших `skills/` / `subagents/` по образцу Cursor.

**Применяй:**
- Ставь plugin: `/add-plugin cursor-team-kit` — не копируй все 18 skills в этот репо без нужды
- Паттерн kit = **skills + subagents + rules**, без обязательных third-party SaaS
- Harness-мышление: `control-cli` / `control-ui` / `verify-this` = локальные проверки, не «поверь модели»
- После чатов с устойчивыми предпочтениями → `workflow-from-chats` (или наш аналог в `docs/` + `SOURCES.md`)
- Перед ship: `deslop` + compile check + узкий PR (`make-pr-easy-to-review` / `review-and-ship`)
- Жёсткий quality gate: `thermo-nuclear-code-quality-review` (skill + Task subagent) после того, как parent собрал diff

**Не делай:**
- Не дублируй весь plugin в `archive/` «на всякий случай» — source на GitHub, MIT
- Не включай `typescript-exhaustive-switch` / `no-inline-imports` глобально, если стек проекта не TS / команда не согласна
- Не путай marketplace plugin с нашими выжимками: plugin исполняется в Cursor; `docs/` — контекст и карта

**Вердикт:** первоклассный эталон для секций `rules-and-skills/` и `subagents/` этого toolkit. Берём **карту когда-что**, при необходимости адаптируем отдельные skills под свои правила.

---

## Что это

Внутренние workflow команды Cursor, упакованные как plugin: CI, review, shipping, control-cli/ui, verify-this, test reliability, cleanup, work summaries. Без обязательных внешних сервисов.

| Компонент | Кол-во | Роль |
|-----------|--------|------|
| Skills | 18 | Процедуры под задачу |
| Subagents | 2 | Фоновый CI watch + строгий quality review |
| Rules | 2 | TS/import hygiene |

Install: `/add-plugin cursor-team-kit`

---

## Skills — карта «когда вызывать»

### Ship / PR

| Skill | Когда |
|-------|--------|
| `new-branch-and-pr` | Новая ветка → работа → PR |
| `review-and-ship` | Структурированный review → commit → PR |
| `make-pr-easy-to-review` | Шумный history / слабое описание PR |
| `pr-review-canvas` | Интерактивный HTML walkthrough diff |
| `get-pr-comments` | Собрать и суммировать review comments |
| `fix-merge-conflicts` | Конфликты → resolve → validate build/tests |

### CI / verify

| Skill | Когда |
|-------|--------|
| `fix-ci` | Упали checks — найти, починить точечно |
| `loop-on-ci` | Крутить CI до зелёного |
| `check-compiler-errors` | Compile / typecheck failures |
| `run-smoke-tests` | Playwright smoke + triage |
| `verify-this` | Доказать/опровергнуть claim (baseline vs treatment) |
| `control-cli` | Локальный harness для CLI/TUI (без внешних сервисов) |
| `control-ui` | Локальный browser/CDP harness для web/IDE/Electron |

### Quality / hygiene

| Skill | Когда |
|-------|--------|
| `deslop` | Убрать AI-slop, выровнять стиль |
| `thermo-nuclear-code-quality-review` | Жёсткий maintainability audit (1k-line, spaghetti, boundaries) |

### Meta / status

| Skill | Когда |
|-------|--------|
| `what-did-i-get-done` | Статус по коммитам за период |
| `weekly-review` | Недельный recap: bugfix / debt / net-new |
| `workflow-from-chats` | Вытащить устойчивые prefs из чатов → skills/rules/docs |

---

## Subagents

| Agent | Когда |
|-------|--------|
| `ci-watcher` | Ждём CI / упал CI — pass/fail + ссылки на failures (можно proactive) |
| `thermo-nuclear-code-quality-review` | Через Task после сбора diff родителем; рубрика из одноимённого skill |

---

## Rules

| Rule | Суть |
|------|------|
| `no-inline-imports` | Импорты только вверху файла |
| `typescript-exhaustive-switch` | Exhaustive `switch` для unions/enums |

Включай в проект только если стек/стиль совпадает.

---

## Перенос в Cursor Project Toolkit

| Идея Team Kit | Наш слой |
|---------------|----------|
| Skills как процедуры | `rules-and-skills/`, `prompting/` |
| Subagents под CI / deep review | `subagents/` |
| `control-cli` / `control-ui` / `verify-this` | harness (см. SRC-002) — проверяй артефактами |
| `workflow-from-chats` | пополнение `docs/` + запись в `SOURCES.md` |
| `deslop` + easy-to-review PR | project-workflow / quality checklist |

### Рекомендуемый минимум для агента на фиче

1. Работа на ветке → `deslop` / compiler check  
2. `review-and-ship` или `new-branch-and-pr`  
3. При CI fail → `fix-ci` / `ci-watcher` / `loop-on-ci`  
4. По запросу качества → thermo-nuclear review  

---

## Архив

По умолчанию **не клонировать**. Source: [cursor/plugins/cursor-team-kit](https://github.com/cursor/plugins/tree/main/cursor-team-kit) (MIT).  
Клон в `archive/repos/cursor-team-kit` — только если нужен offline snapshot или глубокий diff skills.

---

## Источник

- Marketplace: https://cursor.com/marketplace/cursor/cursor-team-kit  
- Source: https://github.com/cursor/plugins/tree/main/cursor-team-kit  
- Реестр: [SRC-004](../SOURCES.md)
