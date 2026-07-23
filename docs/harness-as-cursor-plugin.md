# Harness как Cursor plugin

> **AI-first.** Copy/bootstrap + optional local plugin. Marketplace publish — позже.

## For agents

**Когда читать:** install plugin; сравнить bootstrap vs plugin; runtime coexistence experiment; обновить verdict.

**Вердикт сейчас:** plugin scaffold в repo — `cursor-project-harness` (semver in `plugin/cursor-project-harness/.cursor-plugin/plugin.json`) с autonomous-task, maintain-project-docs, configure-project-integrations, browser-verify, setup-project-environment, model-pinned agents. Локальная копия может быть старее: после update запусти installer и reload Cursor. Bootstrap Essential остаётся default для on-disk docs/scripts/AGENTS merge; native control **templates** и MCP templates только Full.

**Static vs runtime evidence:** mirror hash checks, orchestration SelfTest, and Essential smoke prove **on-disk copy integrity** only. **Runtime coexistence** (plugin hooks + product hooks in Cursor IDE, load order, reload behavior) requires the **runtime coexistence protocol** below plus an external IDE reload step with recorded hook events.

**Применяй:**
- Greenfield (новый продукт) → `scripts/new-project.ps1` / `.cmd` / skill `bootstrap-project`
- Уже есть папка → `scripts/bootstrap-into-project.ps1 -TargetPath … -Mode Essential`
- Rules/skills/hooks в Cursor → `scripts/install-harness-plugin.ps1` (или reload после copy в `~/.cursor/plugins/local/`)
- Runtime coexistence experiment → `scripts/runtime-coexistence.ps1` + `scripts/runtime-coexistence-rollback.ps1`
- Consumers: [harness-consumers.md](harness-consumers.md)

**Не делай:** форкать Team Kit; класть `ship-toolkit` / `add-source` в plugin; claim runtime verified без recorded hook events; claim combined owner без evidence (default **combined_unsupported**).

---

## Runtime coexistence protocol (Wave 4A — implemented tooling)

Reproducible tooling for RUNTIME-01 experiment. **Default:** isolated `%TEMP%` roots — no User-scope HOME writes in SelfTest/tests. **`runtime_verified` remains false** for isolated/synthetic runs; only `-RealProfile` + `-IdeAttested` Record after external IDE reload may qualify (Human Gate).

### Scenarios

| Scenario | Surfaces installed (staging) |
|----------|------------------------------|
| `baseline` | none |
| `essential-only` | workspace `.cursor/hooks` (Essential) |
| `plugin-only` | profile `plugins/local/cursor-project-harness` |
| `combined` | Essential workspace hooks **and** local plugin |

### Actions

| Action | Purpose |
|--------|---------|
| `Prepare` | Write `pre_mutation` state; **transactional backup** to `backup_partial` → verify digest → promote → `backup_complete=true` **before** live mutation; backup failure leaves live untouched (`backup_failed`, no auto-rollback) |
| `Record` | Requires `-InvocationMarker` + prepared phase; scenario-allowed source; `-IdeAttested` only on `-RealProfile` |
| `Finalize` | Owner verdict; **`runtime_verified=false`** unless `-RealProfile` + `-IdeAttested` + recorded owner + **`evidence_complete`** (rollback proof); Record alone never suffices; preserves `evidence_complete` after rollback |
| `Rollback` | Requires `backup_complete`; verifies stored backup digest before touching live; incomplete/mismatch refuses non-destructively |
| `SelfTest` | Isolated cycles **Prepare → Record → Rollback → Finalize** per scenario; never sets `runtime_verified` |
| `-TestOnly` | Simulated profile derived at runtime as `{RunRoot}/simulated_profile` — never persisted in state |

### Metadata journal (only)

Each JSONL event may include: `scenario`, `source`, `event`, `nonce`, `hash`, `elapsed_ms`, `invocation_count`, `context_bytes`.

**Forbidden in journal/output:** payload, username, hostname, absolute/private paths, plugin inventory lists.

Owner rule: choose **essential**, **plugin**, **none**, or **combined_unsupported** from recorded invocations only.

### Phase order (executable)

1. **Prepare** `-InvocationMarker <marker>` — transactional backup when live plugin exists; then install staging surfaces
2. **Record** `-InvocationMarker <marker>` `-Source essential|plugin` — optional `-IdeAttested` on RealProfile only
3. **Rollback** `-InvocationMarker <marker>` — sets `evidence_complete` when live digest proof succeeds; required before Finalize may set `runtime_verified`
4. **Finalize** `-InvocationMarker <marker>` — owner verdict; preserves rollback `evidence_complete`; `runtime_verified=true` only when RealProfile + IdeAttested + owner + prior rollback proof

State stores **booleans + relative `live_surface_id` only** — no absolute profile paths.

### Commands

```powershell
# Isolated SelfTest (no profile mutation)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\runtime-coexistence.ps1 -Action SelfTest

# Manual isolated run (phase order)
$run = Join-Path $env:TEMP ("cptk-coexist-" + [guid]::NewGuid().ToString("n"))
$marker = "manual-1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\runtime-coexistence.ps1 `
  -Action Prepare -Scenario essential-only -RunRoot $run -InvocationMarker $marker
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\runtime-coexistence.ps1 `
  -Action Record -RunRoot $run -InvocationMarker $marker -Source essential -HookEvent sessionStart
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\runtime-coexistence-rollback.ps1 `
  -RunRoot $run -InvocationMarker $marker
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\runtime-coexistence.ps1 `
  -Action Finalize -RunRoot $run -InvocationMarker $marker
```

**Real profile runtime proof (Human Gate):** `-RealProfile -InvocationMarker <marker>` on Prepare; after external IDE reload, Record with `-IdeAttested`; Rollback must succeed (`evidence_complete=true`); only then may Finalize set `runtime_verified=true`. **Record alone is never sufficient.**

Schema helper: `tests/runtime/coexistence-protocol.schema.json` · test: `tests/runtime/test-coexistence-protocol.ps1`.

---

## Критерии (статус)

| Критерий | Статус |
|----------|--------|
| Essential smoke на Windows | done (static/deterministic) |
| Product vs toolkit skills | done |
| ≥2 реальных продукта | done (TG_BOT_PRO, inkavrio_ru) |
| Repo semver in plugin.json | done; live install проверяй после installer |
| Hooks static merge in consumers | done (on-disk copy) |
| Runtime coexistence protocol tooling | done (Wave 4A — isolated SelfTest) |
| Hooks runtime coexistence in Cursor IDE | **unverified** — external reload + real-profile `-IdeAttested` Record required |
| Marketplace publish | optional / human |

### Static hash/smoke vs runtime (normative)

| Layer | What validators prove | Status |
|-------|----------------------|--------|
| **Static** | Byte mirrors (`validate-orchestration`), Essential smoke, parse/dry-run | verified by deterministic scripts |
| **Protocol** | Prepare/Record/Rollback/Finalize isolated SelfTest; TestOnly simulated profile backup proof | tooling verified — **not** IDE runtime |
| **Runtime IDE** | Plugin + product hooks both active; IDE reload; hook event order | **unverified** |

Do not promote “hooks verified outside toolkit” to runtime verified without explicit coexistence evidence.

---

## Layout

```
plugin/cursor-project-harness/
  .cursor-plugin/plugin.json
  rules/product-core.mdc
  ...
scripts/runtime-coexistence.ps1
scripts/runtime-coexistence-rollback.ps1
tests/runtime/test-coexistence-protocol.ps1
```

Install:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\install-harness-plugin.ps1
```

→ `%USERPROFILE%\.cursor\plugins\local\cursor-project-harness` → reload Cursor.

---

## Copy vs Plugin

| Need | Use |
|------|-----|
| On-disk prompting/docs/shim + merge AGENTS | bootstrap Essential |
| Cursor-loaded rules/skills/hooks everywhere | local plugin |
| Coexistence experiment | runtime protocol (isolated default) |
| Team marketplace | publish later (cursor.com/marketplace/publish) |

Официально: [Plugins](https://cursor.com/docs/plugins) · [reference](https://cursor.com/docs/reference/plugins) · SRC-008/009.

---

## Связанное

- [bootstrap-scaffold.md](bootstrap-scaffold.md)
- [harness-consumers.md](harness-consumers.md)
- [cursor-official-plugins.md](cursor-official-plugins.md)
