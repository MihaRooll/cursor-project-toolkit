# SOURCES — реестр внешних ресурсов

Единый список всего, откуда мы что-то взяли в toolkit.

**Правило:** любое заимствование → строка здесь + выжимка в `docs/` (основное). Полная копия — только при необходимости, в `archive/` (сбоку).

| ID | Источник | Тип | Что взяли | Наша docs | Архив | Дата |
|----|----------|-----|-----------|-----------|-------|------|
| SRC-001 | [GitHub for Beginners: roadmap](https://github.blog/developer-skills/github/github-for-beginners-your-roadmap-to-mastering-the-github-essentials/) | article | Git/GitHub essentials, flow, PR, Issues, Actions, security, OSS | [docs/github-for-beginners-essentials.md](docs/github-for-beginners-essentials.md) | — (ссылка достаточна) | 2026-07-19 |
| SRC-002 | [Benchmarks Are Dead (for us) — Poetiq](https://poetiq.ai/posts/benchmarks_are_dead/) | article | Harness > weights, RSI/metasystem, living benchmarks; принцип для toolkit | [docs/harness-over-weights-rsi.md](docs/harness-over-weights-rsi.md) | — (ссылка достаточна) | 2026-07-19 |
| SRC-003 | [Blume](https://useblume.dev/) | tool / docs platform | AI-ready markdown docs: llms.txt, MCP, raw `.md`, zero-config site | [docs/blume-ai-ready-docs.md](docs/blume-ai-ready-docs.md) | — (ссылка достаточна; клон репо — по решению шипить сайт) | 2026-07-19 |
| SRC-004 | [Cursor Team Kit](https://cursor.com/marketplace/cursor/cursor-team-kit) · [source](https://github.com/cursor/plugins/tree/main/cursor-team-kit) | Cursor plugin | 18 skills, 2 subagents, 2 rules — CI/PR/ship/verify/deslop (официальные internal workflows) | [docs/cursor-team-kit.md](docs/cursor-team-kit.md) | — (ставить plugin; клон — только offline snapshot) | 2026-07-19 |
| SRC-005 | [Best practices for coding with agents](https://cursor.com/blog/agent-best-practices) | Cursor blog | Plan Mode, context hygiene, Rules vs Skills, TDD/grind, parallel/cloud | [docs/cursor-agent-best-practices.md](docs/cursor-agent-best-practices.md) | — | 2026-07-19 |
| SRC-006 | [Rules](https://cursor.com/docs/rules) · [Skills](https://cursor.com/docs/skills) | Cursor docs | Primitives: rules/skills/AGENTS.md, frontmatter, discovery paths | [docs/cursor-primitives.md](docs/cursor-primitives.md) | — | 2026-07-19 |
| SRC-007 | [Dynamic context discovery](https://cursor.com/blog/dynamic-context-discovery) | Cursor blog | Static index vs on-demand load; skills/MCP/files pattern | [docs/cursor-dynamic-context.md](docs/cursor-dynamic-context.md) | — | 2026-07-19 |
| SRC-008 | [Plugins docs](https://cursor.com/docs/plugins) · [Marketplace blog](https://cursor.com/blog/marketplace) | Cursor docs/blog | Как пакуются plugins; marketplace | [docs/cursor-official-index.md](docs/cursor-official-index.md) | — | 2026-07-19 |
| SRC-009 | [cursor/plugins](https://github.com/cursor/plugins) (all Cursor-authored plugins) | GitHub repo | continual-learning, thermos, orchestrate, create-plugin, canvases, sdk, … | [docs/cursor-official-plugins.md](docs/cursor-official-plugins.md) · [docs/cursor-official-index.md](docs/cursor-official-index.md) | — (ставить plugins; клон репо — по нужде) | 2026-07-19 |

## Когда копировать в `archive/`

| Ситуация | Действие |
|----------|----------|
| Стабильная публичная статья / docs | Только ссылка в этой таблице |
| Риск исчезновения / paywall / важный снимок | Скопировать в `archive/<id>-slug/` + путь в колонке «Архив» |
| Внешний git-репо с полезными правилами/skills | Prefer submodule или sparse copy в `archive/repos/<name>/` + запись здесь |
| Лицензия запрещает копирование | Только ссылка, выжимка своими словами |

## Как добавлять источник

1. Выдать следующий `SRC-NNN`
2. Добавить строку в таблицу
3. Написать AI-first выжимку в `docs/`
4. При необходимости — положить оригинал/клон в `archive/`
5. Обновить индекс в [`docs/README.md`](docs/README.md)
