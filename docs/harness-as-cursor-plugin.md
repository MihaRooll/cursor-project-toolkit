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
| `Finalize` | Owner verdict; preserves `evidence_complete`; reports `cleanup_complete` / `cleanup_pending` separately; **`runtime_verified=false`** unless RealProfile + IdeAttested + owner + live rollback proof |
| `Rollback` | Requires `backup_complete`; **live plugin restore/remove first** → persist `evidence_complete`; owned staging cleanup best-effort; locked workspace → `cleanup_pending` without invalidating live proof; idempotent rerun finishes cleanup |
| `SelfTest` | Isolated cycles **Prepare → Record → Rollback → Finalize** per scenario; never sets `runtime_verified` |
| `-TestOnly` | Simulated profile derived at runtime as `{RunRoot}/simulated_profile` — never persisted in state |

### Metadata journal (only)

Each JSONL event may include: `scenario`, `source`, `event`, `nonce`, `hash`, `elapsed_ms`, `invocation_count`, `context_bytes`.

**Forbidden in journal/output:** payload, username, hostname, absolute/private paths, plugin inventory lists.

Owner rule: choose **essential**, **plugin**, **none**, or **combined_unsupported** from recorded invocations only.

### Phase order (executable)

1. **Prepare** `-InvocationMarker <marker>` — transactional backup when live plugin exists; then install staging surfaces
2. **Record** `-InvocationMarker <marker>` `-Source essential|plugin` — optional `-IdeAttested` on RealProfile only
3. **Rollback** `-InvocationMarker <marker>` — live plugin restore/remove first → `evidence_complete`; then best-effort owned cleanup (`cleanup_pending` when workspace locked)
4. **Finalize** `-InvocationMarker <marker>` — owner verdict; preserves `evidence_complete`; reports `cleanup_complete` / `cleanup_pending`; optional Rollback rerun clears pending cleanup

State stores **booleans + relative `live_surface_id` only** — no absolute profile paths. Rollback fields: `evidence_complete` (live proof), `cleanup_complete`, `cleanup_pending` (owned RunRoot subtrees only).

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

### Human-Gated trial results (2026-07-23)

Cursor stable **3.12.17** · new window · full phase order on `-RealProfile` runs. Journal stores metadata only (no raw payloads or private paths).

| Trial | Record | Rollback proof | Finalize | Notes |
|-------|--------|----------------|----------|-------|
| **plugin-only** | `-IdeAttested` plugin; harness load events observed (4) | `had_prior=false`; `evidence_complete=true`; live plugin **absent** after rollback | `owner=plugin`; **`runtime_verified=true`** | `cleanup_pending` only — trial `%TEMP%` RunRoot workspace still open; **non-profile** cleanup |
| **combined** (Essential workspace + local plugin) | both `essential` and `plugin` sources; plugin load events (4) + project hook steps (3; two load reports) | `evidence_complete=true`; live plugin **absent** | `owner=combined_unsupported`; **`runtime_verified=false`** | dual active surfaces recorded; owner rule rejects combined |

**Operational decision (this repo workspace):** retain **Essential on-disk hooks** as the sole runtime owner for day-to-day work; **local plugin removed** from profile after trials. **`combined` remains unsupported** until a later coexistence design — do **not** auto-delete/disable product hooks or plugin artifacts in repo. Profile restored; any `cleanup_pending` applies to disposable `%TEMP%` RunRoots only.

No strict-hook or living-eval promotion claimed from these trials alone.

---

## Критерии (статус)

| Критерий | Статус |
|----------|--------|
| Essential smoke на Windows | done (static/deterministic) |
| Product vs toolkit skills | done |
| ≥2 реальных продукта | done (TG_BOT_PRO, inkavrio_ru) |
| Repo semver in plugin.json | done; live install проверяй после installer |
| Hooks static merge in consumers | done (on-disk copy) |
| Runtime coexistence protocol tooling | done (Wave 4A — SelfTest + TestOnly backup) |
| Plugin-only runtime (RealProfile + IdeAttested) | **verified** (Human Gate 2026-07-23); `runtime_verified=true` after rollback proof |
| Combined plugin + Essential runtime | **unsupported** — recorded both sources → `combined_unsupported`; `runtime_verified=false` |
| Marketplace publish | optional / human |

### Static hash/smoke vs runtime (normative)

| Layer | What validators prove | Status |
|-------|----------------------|--------|
| **Static** | Byte mirrors (`validate-orchestration`), Essential smoke, parse/dry-run | verified by deterministic scripts |
| **Protocol** | Prepare/Record/Rollback/Finalize SelfTest; TestOnly backup; locked-subtree cleanup pending | tooling verified |
| **Runtime IDE (plugin-only)** | RealProfile + IdeAttested + rollback live proof | **verified** (2026-07-23 trial) |
| **Runtime IDE (combined)** | Plugin + Essential both active | **unsupported** — owner `combined_unsupported` |

Do not promote strict enforcement or “combined verified” from plugin-only evidence alone.

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
