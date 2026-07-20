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
| SRC-010 | [prompts.chat/prompts](https://prompts.chat/prompts) | community prompt lib | **Не ingest оптом** — шум/one-off ТЗ; политика точечного отбора | [docs/prompts-chat-verdict.md](docs/prompts-chat-verdict.md) | — (не архивировать каталог) | 2026-07-19 |
| SRC-011 | [papercuts](https://github.com/treygoff24/papercuts) · [idea/X](https://x.com/steveruizok/status/2075303919664734295) | CLI / agent tooling | Complaint box для агентов → `.papercuts.jsonl`; triage harness friction | [docs/papercuts.md](docs/papercuts.md) | — (ставить CLI; не клонировать репо обязательно) | 2026-07-19 |
| SRC-012 | [Using GPT-5.6 / latest-model](https://developers.openai.com/api/docs/guides/latest-model) | OpenAI docs | GPT-5.6 family, reasoning/pro/PTC, lean prompts, autonomy boundaries | [docs/openai-gpt56-model-guidance.md](docs/openai-gpt56-model-guidance.md) · [prompting/lean-prompts-autonomy.md](prompting/lean-prompts-autonomy.md) | — | 2026-07-19 |
| SRC-013 | [OpenAI developer docs portal](https://developers.openai.com/) (prompting, reasoning, production, safety, agents, evals) | OpenAI docs map | Курируемый индекс: что полезно при AI-разработке продуктов | [docs/openai-ai-dev-index.md](docs/openai-ai-dev-index.md) | — (не зеркалить portal) | 2026-07-19 |
| SRC-014 | [Getting started with loops](https://claude.com/blog/getting-started-with-loops) · [X/@ClaudeDevs](https://x.com/ClaudeDevs/status/2074208949205881033) | Anthropic / Claude Code blog | Loop types: turn / goal / time / proactive; quality + token; hand-off model | [docs/claude-code-loops.md](docs/claude-code-loops.md) · [prompting/agent-loops.md](prompting/agent-loops.md) | — | 2026-07-19 |
| SRC-015 | [Claude Code prompt library](https://code.claude.com/docs/en/prompt-library) | Anthropic docs | Official starters + 6 prompting patterns; SDLC map; selective for Cursor | [docs/claude-code-prompt-library.md](docs/claude-code-prompt-library.md) | — (не копировать весь каталог) | 2026-07-19 |
| SRC-016 | [UI Skills](https://www.ui-skills.com/) · [ibelick/ui-skills](https://github.com/ibelick/ui-skills) | catalog / CLI | Design-engineering Agent Skills; `npx ui-skills start` router; selective install | [docs/ui-skills.md](docs/ui-skills.md) | — (не vendoring registry) | 2026-07-19 |
| SRC-017 | [ponytail](https://github.com/DietrichGebert/ponytail) | agent skill / rules | Lazy-senior ladder: YAGNI→reuse→stdlib→native→dep→min code; Cursor = copy `.cursor/rules` | [docs/ponytail.md](docs/ponytail.md) | — (ставить в продукт; не Essential default) | 2026-07-19 |
| SRC-018 | [clean-code-javascript](https://github.com/ryanmcdermott/clean-code-javascript) | guide / repo | Clean Code (Martin) adapted for JS: naming, functions, SOLID, async, errors, comments | [docs/clean-code-javascript.md](docs/clean-code-javascript.md) | — (ссылка достаточна; не зеркалить README) | 2026-07-19 |
| SRC-019 | [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) | agent skills pack | 24 lifecycle skills + slash commands + personas; `npx skills add`; Cursor → `.cursor/skills` | [docs/addyosmani-agent-skills.md](docs/addyosmani-agent-skills.md) | — (ставить selective в продукт; не vendoring) | 2026-07-19 |
| SRC-020 | [mattpocock/skills](https://github.com/mattpocock/skills) · [skills.sh](https://skills.sh) | agent skills pack | Composable eng skills: grill, CONTEXT.md, TDD, triage/tickets; user- vs model-invoked; `npx skills@latest add` | [docs/mattpocock-skills.md](docs/mattpocock-skills.md) | — (ставить selective в продукт; не vendoring) | 2026-07-19 |
| SRC-021 | [agentscope-ai/ReMe](https://github.com/agentscope-ai/ReMe) | agent memory toolkit | Local-first Markdown memory: auto_memory/dream, BM25+wikilinks, CLI/MCP/SDK; coding-agent long-term recall | [docs/reme-agent-memory.md](docs/reme-agent-memory.md) | — (opt-in в продукт; не Essential) | 2026-07-19 |
| SRC-022 | [Claude security-guidance](https://code.claude.com/docs/en/security-guidance) · [plugin source](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/security-guidance) | Anthropic / Claude Code plugin | In-session vuln review: per-edit patterns + turn/commit model review; map → Cursor Bugbot/hooks/thermos | [docs/security-in-session-cursor-vs-claude.md](docs/security-in-session-cursor-vs-claude.md) | — | 2026-07-19 |
| SRC-023 | [Cursor Subagents](https://cursor.com/docs/subagents) · [Plan Mode](https://cursor.com/docs/agent/plan-mode) · [Models & pricing](https://cursor.com/docs/models-and-pricing) | Cursor docs | Nested subagents, model pins/fallback, parallel contexts, Plan Mode vs internal autonomous plans | [docs/autonomous-agent-orchestration.md](docs/autonomous-agent-orchestration.md) | — | 2026-07-20 |
| SRC-024 | [Anthropic multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system) · [OpenAI harness engineering](https://openai.com/index/harness-engineering/) · [Symphony](https://openai.com/index/open-source-codex-orchestration-symphony/) | engineering reports | Supervisor/worker topology, context isolation, verification/state-machine patterns; adapt selectively to Cursor | [docs/autonomous-agent-orchestration.md](docs/autonomous-agent-orchestration.md) | — | 2026-07-20 |
| SRC-025 | [Cursor MCP](https://cursor.com/docs/mcp) | Cursor docs | MCP placement local/global/cloud, security model, tool I/O | [docs/mcp-security.md](docs/mcp-security.md) · [docs/cursor-official-index.md](docs/cursor-official-index.md) | — | 2026-07-20 |
| SRC-026 | [Obsidian Help](https://help.obsidian.md/) | docs platform | Vault-as-repo, relative links, no committed wikilinks | [docs/memory-and-obsidian.md](docs/memory-and-obsidian.md) | — | 2026-07-20 |
| SRC-027 | [Cursor Automations](https://cursor.com/docs/automations) · continual-learning plugin | Cursor docs/plugin | Automation-scoped memory as poisonable candidate; not general Agent memory | [docs/memory-and-obsidian.md](docs/memory-and-obsidian.md) · [docs/cursor-official-plugins.md](docs/cursor-official-plugins.md) | — | 2026-07-20 |
| SRC-028 | [cursor/mcp-servers](https://github.com/cursor/mcp-servers) | GitHub repo | Curated MCP list; pin + provenance for profiles | [docs/mcp-security.md](docs/mcp-security.md) · [templates/mcp/](templates/mcp/) | — | 2026-07-20 |
| SRC-029 | [Cursor Cloud Agents](https://cursor.com/docs/cloud-agent) · [Hooks](https://cursor.com/docs/hooks) | Cursor docs | Surfaces matrix; session-start context; doctor/stage injection; strict hook templates (Full opt-in) | [docs/project-environment.md](docs/project-environment.md) · [docs/project-state.md](docs/project-state.md) · [docs/harness-evidence-and-enforcement.md](docs/harness-evidence-and-enforcement.md) | — | 2026-07-20 |
| SRC-030 | [Agent permissions](https://cursor.com/docs/agent/permissions) · [Sandbox](https://cursor.com/docs/agent/sandbox) · [Browser](https://cursor.com/docs/agent/browser) | Cursor docs | Native controls opt-in templates; Browser Human Gate | [docs/cursor-native-controls.md](docs/cursor-native-controls.md) · [templates/cursor/](templates/cursor/) | — | 2026-07-20 |

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
