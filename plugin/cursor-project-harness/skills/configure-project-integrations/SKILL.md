---
name: configure-project-integrations
description: Предложить и dry-run интеграции проекта (MCP, env, scopes); применение только после явного подтверждения. Когда просят MCP, GitHub read-only, Context7/docs или wiring integrations.
---

# configure-project-integrations

## Когда

- Запрос на MCP server, GitHub read-only, vendor docs (Context7) после gap `@Docs`
- Нужен dry-run merged local + global MCP перед записью `.cursor/mcp.json`
- Проверка дубликатов с native tools / уже включёнными серверами

## Availability

| Surface | configure skill | MCP templates | validate-mcp-profiles |
|---------|-----------------|-----------------|------------------------|
| Essential bootstrap | **no** | no | no |
| Full bootstrap | yes (on-disk) | `templates/mcp/` | yes |
| Local plugin 0.5.0 | yes (Cursor-loaded) | — (use product Full or toolkit) | — |
| Toolkit repo | yes | yes | yes |

Essential-only products: propose manually or re-seed **Full** / install **local plugin** / work from toolkit before MCP wiring.

## Шаги (read-only propose)

1. Read product docs when present: `docs/mcp-security.md`, `docs/project-integrations.md` (Full bootstrap). If absent, apply policy below.
2. **Detect** — stack, enabled native/@Docs, existing global + project MCP keys.
3. **Dedupe** — skip profiles where `redundant_if` matches enabled surface.
4. **Dry-run** — show merged config, env refs (`${env:…}` only), scopes, mutation tools, placement (local/cloud/both).
5. **Explicit confirmation** — user must approve before any write.
6. **Implementer apply** — только implementer пишет `.cursor/mcp.json` / env templates.
7. **Static validate** (when `scripts/validate-mcp-profiles.ps1` exists in product or toolkit):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-mcp-profiles.ps1 -ProfilesRoot templates\mcp\profiles
```

## MCP policy (self-contained)

- Pins: npm/pypi/docker identity must appear in **command/args** only; reject `latest`/unpinned/desync and conflicting install tokens in command/args.
- Secrets: allow `Bearer ${env:NAME}` and whole-header `${env:AUTH_HEADER}`; reject every `Basic <token>` form (including short tokens and `Basic ${env:FOO}`).
- `prod_forbidden`: bounded scan of all fragment strings for prod hosts (URI authority, path/query/fragment, `host=` prose).
- Mutation tools matching token-anchored keywords `(^|[_-])(create|write|update|delete|merge|push|deploy|transfer|remove|destroy|drop)($|[_-])` must be declared in `mutation_tools` — bare substrings (e.g. `list_deleted_items`) do not match; undeclared matches **always fail** (fail-closed; `proposal-only` does not exempt).
- Never auto-enable strict hooks; templates live under `templates/hooks/` (Full opt-in).

## Human Gate (T4) — stop and packet

- Interactive OAuth / credentials entry
- Mutation-capable MCP allowlists
- Dashboard / Automation create or promote
- Production or external mutation

Config-only pinned package + env interpolation refs — **не** T4.

## Не делай

- Не пиши `.cursor/mcp.json` из propose/dry-run фазы
- Не добавляй secrets, `envFile`, `latest`, prod hosts в committed profiles
- Не включай Obsidian/filesystem/Playwright MCP по умолчанию
- Не ссылайся на `../../docs/` paths — используй product `docs/` или policy выше

## См.

- `templates/mcp/README.md` (Full)
- `templates/mcp/profiles/` (Full)
- Rule: product-core + autonomous-orchestration for tier gates
