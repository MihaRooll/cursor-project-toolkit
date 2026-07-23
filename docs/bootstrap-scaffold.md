# Toolkit как bootstrap-каркас нового проекта

> **AI-first.** Этот репо — не «папка с заметками», а **среда для ИИ-агентов**, которую накатывают на новый проект.

## For agents

**Когда читать:** старт нового продукта; вопрос «зачем этот репо»; команда bootstrap; что копирует Essential.

**Применяй:**
- Greenfield **из клона toolkit** → `scripts/new-project.ps1` / `.cmd` / skill `bootstrap-project` («новый проект name: цель»)
- Уже есть папка → из toolkit: `scripts/bootstrap-into-project.ps1 -TargetPath … -Mode Essential`
- Essential = **product** harness (не toolkit meta-skills); `product-brief` / `first-chat` / `docs-map.json` пишет только `new-project`, не Essential
- Living docs assets (docs + `maintain-project-docs` + `project-docs-lifecycle`) копируются в Essential; map seed — day-0 only
- Papercuts в авто: hooks логируют failed shells; ручной `add` — для всего остального

**Не делай:** копировать `archive/` без нужды; затирать AGENTS без Force; тащить `ship-toolkit` / `add-source` в продукт; запускать `new-project.ps1` **внутри** уже bootstrapped продукта (скрипта там нет — только из клона toolkit).

---

## Модель

```
cursor-project-toolkit  (источник истины / библиотека)
        │
        │  greenfield: new-project.ps1  →  (calls Essential + brief/first-chat)
        │  existing:   bootstrap-into-project.ps1 -Mode Essential
        ▼
my-new-app/             (продукт + скопированный harness)
  AGENTS.md
  .cursor/rules|skills|hooks   (product subset)
  prompting|roles|subagents    (Essential subset)
  docs/ (минимум или Full)
  .papercuts.jsonl             (растёт в продукте)
  vendor/cursor-project-toolkit  (опционально, -WithSubmodule)
```

| Режим | Что копируется |
|-------|----------------|
| Essential | product rules/skills + hooks + papercuts + ключевые docs + Essential prompting/roles/subagents |
| Full | + весь docs/SOURCES/папки toolkit + все skills/rules + `templates/mcp` + `templates/cursor` + `templates/hooks` (opt-in) + `tests/living-eval` + `validate-living-evals.ps1` + `validate-mcp-profiles.ps1` + `validate-recovery.ps1` + `tests/recovery` |
| `-WithSubmodule` | + `git submodule add` → `vendor/cursor-project-toolkit` (нужен git init в target) |

---

## Essential: product vs toolkit

| Слой | В продукт (Essential) | Только toolkit |
|------|----------------------|----------------|
| Skills | `review-papercuts`, `autonomous-task`, `maintain-project-docs`, `browser-verify`, `setup-project-environment` | `add-source`, `bootstrap-project`, `distill-doc`, `ship-toolkit`, `configure-project-integrations` |
| Rules | `product-core.mdc`, `skills-ru-description.mdc`, `autonomous-orchestration.mdc`, `project-docs-lifecycle.mdc` | `toolkit-core.mdc`, `docs-ai-first.mdc` |
| Agents | Grok orchestrator/reviewer/verifier, Composer implementer, Sol arbiter | — |
| Prompting | README + plan/context/verify + lean-autonomy | `constraint-first.md`, `agent-loops.md` (Full) |
| Roles | implementer, reviewer | docs-distiller (Full) |
| Subagents | verifier brief | explorer, parallel-worker (Full) |

Шаблон rule: `templates/project-rules/product-core.mdc`.

Автономный change/build/fix routing: [autonomous-agent-orchestration.md](autonomous-agent-orchestration.md) (delegation-first: Main control plane, Composer product writes T0–T3). Living docs: [living-documentation.md](living-documentation.md). T0–T3 продолжают без routine approval; T4/destructive/external writes human-gated.

---

## Авто-papercuts

| Слой | Поведение |
|------|-----------|
| `afterShellExecution` | exit ≠ 0 → auto `papercuts add` (лимит 8/день, dedupe) |
| `sessionStart` | HOME + короткий reminder в контекст |
| `stop` | раз в день nudge, если есть open cuts |
| Manual | `papercuts add` / shim для docs/cwd/missing tools |

---

## Команды (из клона toolkit)

```powershell
# Greenfield (папка + git + Essential + brief + first-chat + docs-map):
.\scripts\new-project.cmd -Name my-app -Goal "цель одной фразой"

# Re-seed существующей папки (harness only):
.\scripts\bootstrap-into-project.ps1 -TargetPath C:\work\my-app -Mode Essential
# опционально: -Mode Full | -WithSubmodule
```

Чеклист: [new-project-bootstrap.md](../project-workflow/new-project-bootstrap.md).

## Smoke / verify (после правок harness)

**Рекомендуемый checkpoint (toolkit root):**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-harness.ps1 -Profile Quick
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-harness.ps1 -Profile Full
```

Quick — 13 static checks по одному разу; Full = Quick + один `smoke-bootstrap -OracleOnly`. `verify-harness.ps1` **не** копируется в Essential/Full.

**Legacy self-contained** (совместимость; может дублировать Quick head):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\parse-check-ps1.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\smoke-bootstrap.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\smoke-portability.ps1
```

Default smoke target: `%TEMP%\<GUID>`; caller pre-existing path → hard reject; junction/reparse root → hard reject. При падении: `-KeepOnFailure`.

Ожидание Full/legacy: `VERIFY_HARNESS_PASS` / `ALL_OK` + `SMOKE PASS` или `SMOKE ORACLE PASS`; `PORTABILITY_SMOKE_PASS`; ownership tests: `tests\portability\test-smoke-target-safety.ps1` → `SMOKE_TARGET_SAFETY_PASS`. В Essential target — product skills/rules; **нет** toolkit-only поверхности (`verify-harness`, `ship-toolkit`, `toolkit-core`, …).

**Portability smoke** (`smoke-portability.ps1`): PS 5.1, temp roots with spaces/Unicode, `CPTK_PORTABILITY_SMOKE=1` skips User-scope HOME during bootstrap. Под `verify-harness Full` skip-токены (`SKIP`, `PORTABILITY_SMOKE_SKIP`) → fail-closed. Standalone: `CPTK_SKIP_PORTABILITY=1` / `CPTK_PORTABILITY_NESTED_REENTRY=1` по-прежнему могут skip (вне verify-harness).

Strict hooks + living-eval: [harness-evidence-and-enforcement.md](harness-evidence-and-enforcement.md) (Full opt-in; toolkit skill `/review-harness-evidence` — **not** in Essential product surface).

**Merge (частично):** AGENTS → append snippet; `hooks.json` → merge papercuts events (не wipe).
**Всегда overwrite при Essential:** `product-core.mdc` (`-Always`), papercuts hook `.ps1`.
`-AllowExisting` на `new-project` = тот же Essential refresh + skip day-0 (`product-brief`, `first-chat`, `docs-map.json` — skip-if-exists; parseable map never overwritten).
Consumers: [harness-consumers.md](harness-consumers.md).

---

## Plugin

Local plugin: `plugin/cursor-project-harness` + `scripts/install-harness-plugin.ps1`.  
Детали: [harness-as-cursor-plugin.md](harness-as-cursor-plugin.md).

---

## Связанное

- [papercuts.md](papercuts.md)
- [harness-consumers.md](harness-consumers.md)
- [wsl-windows-stability.md](wsl-windows-stability.md) — PowerShell encoding / `${var}`
- [new-project-bootstrap.md](../project-workflow/new-project-bootstrap.md)
