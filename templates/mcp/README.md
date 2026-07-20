# MCP profile templates (opt-in)

> **AI-first.** Proposal-only profiles for Full bootstrap. Essential never ships active MCP config.

## For agents

**When to read:** user asks to add MCP; after `@Docs` gap for vendor docs; before writing `.cursor/mcp.json`.

**Workflow:**
1. **Propose** — pick or adapt a profile under `profiles/<id>.json`
2. **Validate** — `scripts/validate-mcp-profiles.ps1 -ProfilesRoot templates/mcp/profiles`
3. **Apply** — only after explicit confirmation; implementer writes merged `.cursor/mcp.json`

Use skill `/configure-project-integrations` for detect → dedupe → dry-run → confirm → apply.

**Do not:** copy profiles to Essential products; commit secrets; use `latest`; enable prod hosts when `prod_forbidden: true`.

---

## Profiles

| File | Purpose |
|------|---------|
| [github-readonly.json](profiles/github-readonly.json) | Pinned official GitHub read-only (stdio/npm) |
| [context7-docs.json](profiles/context7-docs.json) | Vendor docs MCP proposal after native `@Docs` gap (http/none) |

Filename must equal profile `id`. Each profile has exactly one `mcpServers` entry in `mcp_fragment`.

---

## Related

- [docs/mcp-security.md](../../docs/mcp-security.md)
- [docs/project-integrations.md](../../docs/project-integrations.md)
