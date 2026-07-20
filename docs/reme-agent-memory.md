# ReMe — Memory Management Kit for Agents

> **AI-first.** Источник: [SRC-021](../SOURCES.md) — [agentscope-ai/ReMe](https://github.com/agentscope-ai/ReMe) (Apache-2.0) · docs: [docs.agentscope.io](https://docs.agentscope.io/) · site: [reme.agentscope.io](https://reme.agentscope.io). Local-first memory: conversations/resources → searchable editable Markdown.

## For agents

**Когда читать:** нужен long-term memory слой за пределами `AGENTS.md` / одного чата; пользователь кинул ReMe / MemoryScope; LLM-wiki / procedural memory для coding agent.

**Применяй:**
1. В **продукте** (не toolkit meta): `pip install "reme-ai[core]"` (Python 3.11+) → `reme start`
2. Memory = файлы: frontmatter + wikilinks; человек и агент читают/правят одинаково
3. Flow: capture → index → consolidate → recall (`auto_memory` → `daily/` → `auto_dream` → `digest/`)
4. Integration: CLI / HTTP / MCP / SDK; Claude Code → MCP + `plugins/reme`; Cursor/прочие → `skills/reme_memory/SKILL.md` + CLI
5. Default search: BM25 + wikilinks; embeddings **opt-in** (нужен config + API key)

**Не делай:**
- Ставить ReMe в Essential toolkit bootstrap / local harness plugin
- Коммитить `.env` / API keys / сырые session с секретами
- Путать с Cursor [`continual-learning`](cursor-official-plugins.md) (prefs → `AGENTS.md`) или Matt [`CONTEXT.md`](mattpocock-skills.md) (shared language) — другой слой
- Включать embedding/auto_* без `LLM_API_KEY` и явной нужды

**Вердикт:** **USE on demand** когда продукту нужна file-based long-term memory / wiki. Toolkit держит карту. Для prefs в Cursor чаще хватает continual-learning + наш `AGENTS.md`.

---

## Quick start

```powershell
pip install "reme-ai[core]"
# .env: LLM_API_KEY + LLM_BASE_URL для auto_memory / auto_dream / auto_resource
reme start
# default http://127.0.0.1:2333  — или: reme start service.port=8181
reme version
reme search query="…" limit=5
reme write path=digest/wiki/… name="…" description="…" content="…"
reme read path=digest/wiki/… start_line=1 end_line=40
```

Без LLM: file ops, BM25, wikilinks, proactive topics read.
С LLM: distillation/consolidation. Embedding — отдельно в `reme/config/default.yaml`.

---

## Workspace layout

```text
<workspace_dir>/
  metadata/     # indexes, graphs
  session/      # raw dialogs (jsonl, agentscope, claude_code, …)
  resource/     # external materials by date
  daily/        # light cards + interests.yaml
  digest/       # long-term: personal/ | procedure/ | wiki/
```

| Job | Entry | Output |
|-----|--------|--------|
| `auto_memory` | hook / CLI | `session/` + `daily/<date>/…` |
| `auto_resource` | watcher / CLI | daily resource cards |
| `auto_index` / `reindex` | background | BM25 + wikilink (+ optional vectors) |
| `auto_dream` | cron / CLI | `digest/**`, interests |
| `proactive` | before act | topics for host agent to consider |

---

## Integration paths

| Host | Path |
|------|------|
| Claude Code | MCP service + [plugins/reme](https://github.com/agentscope-ai/ReMe/tree/main/plugins/reme) (skill + Stop hook) |
| Cursor / Codex / CLI agents | Copy [skills/reme_memory/SKILL.md](https://github.com/agentscope-ai/ReMe/blob/main/skills/reme_memory/SKILL.md); call `reme …` |
| QwenPaw / Python apps | Python SDK |
| Any | HTTP API on local service |

Команды агенту чаще всего: `search` / `read` / `write` / `edit` / `auto_memory` / `auto_dream` / `proactive`. Полный список: `reme help`.

---

## Когда НЕ нужен ReMe

| Нужда | Проще |
|-------|--------|
| Prefs / facts → always-on agent instructions | `/add-plugin continual-learning` → `AGENTS.md` |
| Domain jargon, меньше verbosity | Matt `grill-with-docs` → `CONTEXT.md` |
| Одноразовый handoff чата | [continue-chat-prompt](../project-workflow/continue-chat-prompt.md) / Matt `handoff` |
| Docs для агентов в репо | Наш `docs/` AI-first + [dynamic context](cursor-dynamic-context.md) |

ReMe имеет смысл при **кросс-сессионной** накопительной памяти (стиль, решения, procedures, wiki), editable вне IDE.

---

## Связь с toolkit

| Тема | Файл |
|------|------|
| Files as context | [cursor-dynamic-context.md](cursor-dynamic-context.md) |
| Cursor memory plugin | [cursor-official-plugins.md](cursor-official-plugins.md) (`continual-learning`) |
| Shared language | [mattpocock-skills.md](mattpocock-skills.md) |
| Harness compound loop | [papercuts.md](papercuts.md) — friction ≠ long-term memory |
| Essential bootstrap | [bootstrap-scaffold.md](bootstrap-scaffold.md) — не тащить ReMe default |

---

## Источник

- https://github.com/agentscope-ai/ReMe
- https://reme.agentscope.io
- Paper (ACL 2026 Findings): *Remember Me, Refine Me*
- [SRC-021](../SOURCES.md)
