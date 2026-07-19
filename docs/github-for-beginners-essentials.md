# GitHub для начинающих: выжимка essentials

> Формат: **AI-first → human-second**. Сначала правила и факты для агента, пояснения — вторичны.

Краткая выжимка из [GitHub Blog](https://github.blog/developer-skills/github/github-for-beginners-your-roadmap-to-mastering-the-github-essentials/) (Polly Davidson, 15 июля 2026).

## For agents

**Когда читать:** задачи с git remote, ветками, PR, Issues, Actions, security, OSS-вкладом.

**Применяй:**
- Работай через GitHub flow: branch → commit → push → PR → merge (не пушь в `main` без явной просьбы пользователя)
- Имена веток: описательные (`fix-login-bug`, `add-dark-mode`)
- PR: маленький diff, ясный title/description, self-review; линкуй issues через `Closes #N` / `Fixes #N` / `Resolves #N`
- Не коммить секреты, `.env`, credentials; учитывай `.gitignore`
- Issues = задачи/баги; Projects = доска статусов
- Actions = автоматизация в `.github/workflows/*.yml`
- Open source без прав на репо: fork → branch → PR в upstream

**Не делай:** force-push в main/master; skip hooks без запроса; коммит секретов; огромные PR «на всё сразу».

---

## Part 1. Ориентация

### Version control и Git

- **Version control** — система, которая отслеживает изменения файлов во времени. **Git** — самый распространённый инструмент для этого.
- Три зоны Git:
  1. **Working directory** — где правишь файлы
  2. **Staging area** — что готово к сохранению
  3. **Local repository** — история снимков (коммитов)
- Базовый цикл: `git status` → `git add` → `git commit`
- «Push your code» = загрузить локальные коммиты на GitHub

### Аккаунт и безопасность

- GitHub-аккаунт = developer identity → защищай его
- Включи **2FA**: Settings → Password and authentication
- Сохрани **recovery codes** в password manager
- **Profile README**: публичный репо с именем = username → README отображается на профиле

### Команды на каждый день

| Команда | Зачем |
|--------|--------|
| `git config --global user.name "..."` | Имя в коммитах |
| `git init` | Сделать папку Git-репозиторием |
| `git clone <url>` | Локальная копия remote-репо |
| `git status` | Что изменилось / что в stage |
| `git add .` | Добавить изменения в stage |
| `git commit -m "message"` | Сохранить снимок |
| `git switch -c <branch>` | Создать ветку и перейти |
| `git push` | Отправить коммиты на GitHub |
| `git pull` | Забрать и влить изменения с GitHub |
| `git merge <branch>` | Влить другую ветку в текущую |

Запоминать весь Git не нужно — хватает этого набора.

---

## Part 2. Первый проект

### Репозиторий

- **Repo** = папка проекта с историей и возможностью совместной работы
- Создать: New → имя → public/private → добавить **README** (витрина проекта)
- Полезно сразу: **`.gitignore`** (не трекать мусор: зависимости, build, system files) и **license**

### Markdown

- Лёгкий язык разметки для README, Issues, PR и комментариев на GitHub
- Документация становится читаемой без тяжёлых редакторов

### GitHub flow

Повторяемый безопасный цикл:

1. Clone
2. Branch
3. Changes
4. Commit
5. Push
6. Pull request → review → merge

Тот же loop работает не только для кода — например, для общих AI-промптов в репо: правка на ветке → PR → ревью → merge → у всех актуальная версия.

**Tip:** имена веток вроде `fix-login-bug`, `add-dark-mode`.

---

## Part 3. Коллаборация

### Pull request

- **PR** = предложение влить изменения из одной ветки в другую + место для ревью и обсуждения
- Пиши ясный title/description, линкуй issues, сначала сделай self-review
- **Меньшие PR** проще ревьюить, реже ломают код, дают чище историю

### Merge и конфликты

- Merge = влить проверенные изменения в целевую ветку
- **Merge conflict** = две ветки тронули одни и те же строки; Git просит выбрать, что оставить → resolve → merge

### Issues и Projects

- **Issues** — задачи, баги, идеи (assign, labels, обсуждение)
- **Projects** — доска (Kanban) над issues
- Связка PR ↔ Issue: в описании PR пиши `Closes #42` / `Fixes #42` / `Resolves #42` → после merge issue закрывается сам (и двигается в Done на board)

---

## Part 4. Уровень выше

### GitHub Actions

- CI/CD и автоматизация внутри GitHub
- Workflows в `.github/workflows/*.yml`: событие (trigger) → шаги (tests, deploy, labeling и т.д.)

### GitHub Pages

- Бесплатный хостинг: `username.github.io/repo-name`
- Settings → Pages → deploy from branch
- Даже private-репо может публиковать public-сайт (удобно для портфолио/docs)

### Безопасность

Security — привычка, не финальный шаг. Для public-репо бесплатно доступны возможности вроде:

| Инструмент | Что делает |
|-----------|------------|
| **Secret scanning** | Ловит случайно закоммиченные ключи/секреты |
| **Dependabot** | Следит за уязвимостями в зависимостях, открывает PR на обновление |
| **CodeQL** | Анализирует код на рисковые паттерны |

**Важно:** риск библиотеки ты наследуешь в момент импорта — даже если уязвимый код писал не ты.

### Open source

- Ищи проекты с README, `CONTRIBUTING.md`, license и issues с лейблом **`good first issue`**
- **Branch** — параллельная работа *внутри* репо, куда у тебя есть доступ
- **Fork** — полная копия репо *в твой* аккаунт (когда нет прав писать в оригинал)
- Типичный путь: fork → branch в fork → PR в оригинальный репо

---

## Чеклист применения в toolkit

- [ ] Репо с README + `.gitignore` (+ license при публикации)
- [ ] Работа через GitHub flow (ветка → PR → merge), не напрямую в `main` без причины
- [ ] Issues для задач; в PR — `Closes #N`
- [ ] Маленькие PR, говорящие имена веток
- [ ] Actions для повторяемых проверок
- [ ] Secret scanning / Dependabot включены
- [ ] Общие промпты/правила — тоже через PR, как код

---

## Источник

- Реестр: [SRC-001](../SOURCES.md)
- Статья: https://github.blog/developer-skills/github/github-for-beginners-your-roadmap-to-mastering-the-github-essentials/
- Docs: https://docs.github.com
