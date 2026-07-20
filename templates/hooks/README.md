# Strict hook templates (Full / opt-in only)

> **Never merge** `hooks.strict.example.json` into active `.cursor/hooks.json` or the plugin. Promotion requires human signoff via `/review-harness-evidence`.

## For agents

- **When:** Full bootstrap or manual opt-in after evidence review; dry-run with `dry-run-strict-hooks.ps1`.
- **Apply:** Copy scripts to product; register events from `hooks.strict.example.json` only after human approval.
- **Do not:** Ship in Essential; auto-enable; add `server`/`server_name` to beforeMCP stdin.

## Files

| File | Role |
|------|------|
| `strict-before-shell.ps1` | Deny dangerous shell commands; stdin `command`, `cwd`, `sandbox` |
| `strict-before-mcp.ps1` | Deny destructive tools / production mutations; stdin `tool_name`, `tool_input`, `url` **or** `command` |
| `hooks.strict.example.json` | Example registration with `failClosed: true` |
| `dry-run-strict-hooks.ps1` | Local V-11 allow/deny/malformed selftest |

## Deny patterns

**Shell** (`command`): `(?i)(rm\s+-rf\s+/|git\s+push\s+--force|format\s+[A-Z]:)`

**MCP** (`tool_name`): `(?i)(delete|drop|destroy|force_push)`

**MCP production** (substring in `tool_input` / `url` / `command`): `api.production.`, `/prod/`, `"environment":"production"`, `"force":true`, `"drop":true`, `kubectl apply`, `terraform apply`, `npm publish`

## Dry-run

```powershell
'{"command":"echo hi","cwd":"C:\tmp","sandbox":true}' | powershell -NoProfile -File templates/hooks/strict-before-shell.ps1
powershell -NoProfile -File templates/hooks/dry-run-strict-hooks.ps1
```

See [harness-evidence-and-enforcement.md](../../docs/harness-evidence-and-enforcement.md).
