# Skills: русские описания в меню `/`

> Формат: **AI-first → human-second**. Стандарт этого репозитория.

## For agents

**Когда читать:** создание или правка любого `SKILL.md` в `.cursor/skills/` (и зеркал в `rules-and-skills/`).

**Применяй:**
- Поле `description` в YAML frontmatter — **на русском** (это текст в меню `/`)
- В `description` пиши: что делает + когда вызывать + типичные фразы пользователя на русском
- `name` и имя папки — **латиница-kebab** (`add-source`), не переводить
- Заголовок `# …` в теле — можно по-русски, с `(name)` в скобках
- Тело skill: шаги на русском; технические идентификаторы (`SOURCES.md`, git) оставляй как есть

**Не делай:**
- Английский `description` у project skills этого репо
- Кириллицу в `name` / имени папки
- Путать с built-in Cursor (`/babysit`, `/create-hook`) — их описания не контролируем

---

## Зачем

В меню `/` пользователь видит `description`. Репо ориентировано на русскоязычную работу → описания наших skills на русском. Идентификаторы остаются ASCII для совместимости с Cursor.

## Шаблон

```markdown
---
name: my-skill
description: Кратко по-русски что делает. Когда просят «…», «…».
---

# Русский заголовок (my-skill)

## Когда использовать
- …
```

## Примеры (canonical)

| name | description (RU) |
|------|------------------|
| `add-source` | Добавить внешний ресурс в toolkit… |
| `distill-doc` | Сделать или переписать документ AI-first… |
| `ship-toolkit` | Закоммитить и запушить изменения toolkit… |
| `review-papercuts` | Разобрать backlog papercuts… |
| `bootstrap-project` | Развернуть harness toolkit в новый проект… |

Живые файлы: [`.cursor/skills/`](../.cursor/skills/).

## Чеклист нового skill

- [ ] `name` = имя папки, kebab-case, латиница
- [ ] `description` на русском, 1–2 предложения, есть триггеры «когда»
- [ ] Тело: `## Когда использовать` / шаги на русском
- [ ] Запись в `rules-and-skills/README.md` при необходимости

---

## Связанное

- Примитивы: [cursor-primitives.md](cursor-primitives.md)
- Стандарт docs: [README.md](README.md)
- Rule: `.cursor/rules/skills-ru-description.mdc`
