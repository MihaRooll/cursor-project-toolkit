# Cursor Project Toolkit

## Цель репозитория

Собрать в одном месте всё самое актуальное и полезное по разработке и ведению проектов с AI-агентами — чтобы из отдельных практик получилась **синергия с максимальной эффективностью**.

Репозиторий — живой toolkit: рекомендации, шаблоны и **исполняемый harness** для Cursor.

## Аудитория документации

**Сначала ИИ, потом люди.**

1. **ИИ-агенты** — основной потребитель: факты, команды, чеклисты, роли, правила применения  
2. **Люди** — вторичный: быстрый обзор, навигация, ссылки на источники  

## Live harness (уже в репо)

| Что | Где |
|-----|-----|
| Agent instructions | [`AGENTS.md`](AGENTS.md) |
| Always-on rules | [`.cursor/rules/`](.cursor/rules/) |
| Skills | [`.cursor/skills/`](.cursor/skills/) — `add-source`, `distill-doc`, `ship-toolkit` |
| Session / ingest DoD | [`project-workflow/`](project-workflow/) |

Как писать docs: [`docs/README.md`](docs/README.md).  
Карта official Cursor: [`docs/cursor-official-index.md`](docs/cursor-official-index.md).

### Рекомендуемые marketplace plugins

```
/add-plugin cursor-team-kit
/add-plugin continual-learning
```

## Что собираем

| Область | Содержание |
|--------|------------|
| **Промптирование** | Лучшие практики промптов, паттерны задач, антипаттерны |
| **Роли** | Роли агента и когда их включать |
| **Субагенты** | Делегирование, параллельные агенты |
| **Правила и skills** | Cursor rules, skills, hooks |
| **Ведение проектов** | Планирование, DoD, handoff |
| **Документация** | Выжимки AI-first → human-second |

## Принцип

1. **Актуальность** — рабочие и свежие подходы  
2. **Применимость** — агент и человек используют сразу  
3. **Синергия** — промпты + роли + субагенты + docs  
4. **Эффективность** — меньше хаоса, больше предсказуемого результата  
5. **Dynamic context** — короткий индекс, тело по запросу (`docs/` vs `archive/`)

## Два слоя знаний

| Слой | Где | Зачем |
|------|-----|--------|
| **Основное** | `docs/`, `.cursor/`, шаблоны | То, с чем работают агент и команда |
| **Архив** | `archive/` | Полные копии источников (сбоку) |

Реестр внешнего: [`SOURCES.md`](SOURCES.md).

## Структура

```
cursor-project-toolkit/
├── README.md
├── AGENTS.md                 # инструкции агенту
├── SOURCES.md                # реестр SRC-NNN
├── .cursor/rules/            # project rules
├── .cursor/skills/           # project skills
├── archive/                  # полный архив (опционально)
├── docs/                     # основная документация (AI-first)
├── prompting/
├── roles/
├── subagents/
├── rules-and-skills/         # заметки; canonical skills в .cursor/skills/
└── project-workflow/         # чеклисты сессии / ingest
```

### Docs highlights

- [Cursor official index](docs/cursor-official-index.md) · [best practices](docs/cursor-agent-best-practices.md) · [primitives](docs/cursor-primitives.md) · [dynamic context](docs/cursor-dynamic-context.md) · [plugins](docs/cursor-official-plugins.md) · [Team Kit](docs/cursor-team-kit.md)
- [GitHub essentials](docs/github-for-beginners-essentials.md) · [Harness/RSI](docs/harness-over-weights-rsi.md) · [Blume](docs/blume-ai-ready-docs.md)

---

**Миссия:** максимальная эффективность разработки за счёт согласованной системы практик — от промпта до документации и живого harness в `.cursor/`.
