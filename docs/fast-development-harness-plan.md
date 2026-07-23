# Fast development harness — implementation architecture

> **AI-first.** Normative architecture distilled from three research/review cycles. Executable contract: create **`toolkit-fast-loop-v2`** (cycle 1); do **not** resume **`toolkit-fast-loop-v1`**.

## For agents

**When to read:** before any fast-loop implementation (`change`/`build`/`fix` touching oracle, CI, verification policy).

**Apply:** preserve T0–T4 orchestration; implement **Quick/Full oracle first**, then one unconditional Windows CI, then small policy/hygiene slices. Waves 0–3 only until graduation gates; Waves 4–6 gated.

**Do not:** copy advisory `Рекомендация ГПТ про/` into normative docs; resume blocked v1 contract; treat static validators as runtime proof; add planner-first or conditional CI before metrics.

---

## Verdict (unchanged)

| Area | Decision |
|------|----------|
| T0–T4 orchestration | **Preserve** — Main control plane; Composer sole writer T0–T3; Grok orch/verify; Sol T3 pre-write only |
| Primary bottleneck | Incomplete/unsafe full oracle + no CI — not test count |
| P0 order | Quick/Full oracle → unconditional Windows CI → policy/hygiene |
| Deferred now | Changed-path planner, conditional CI, cache, root Pester/pytest core, Nx/Bazel, remote cache, strict deny gates |

Observed full smoke ~105s on Windows — acceptable for first CI gate; optimize only after stable CI metrics.

---

## Target development model

1. **Edit/fix:** narrow native target or repro only.
2. **Local completion:** `verify-harness.ps1 -Profile Quick` — all fast static/policy validators at toolkit root, each exactly once.
3. **Pre-merge / main:** `verify-harness.ps1 -Profile Full` = Quick + exactly one bootstrap/portability oracle (`smoke-bootstrap -OracleOnly`).
4. **Manual Cursor checks:** model availability, plugin/hook runtime, actual surface — separate from deterministic scripts.
5. **Changed-path planner:** Wave 6 only after graduation triggers (p95 > 5 min, ≥20 CI runs, stable oracle).

---

## Quick / Full oracle (Wave 1)

### Invariants

| ID | Rule |
|----|------|
| INV-1 | Quick runs each listed check once at toolkit root. Full = Quick + one `-OracleOnly` oracle. `smoke-bootstrap` stays self-contained; **`verify-harness` not on Essential/Full copy lists**. |
| INV-2 | Required stage set equality; each stage emits `STAGE_OK <id>`; missing / nonzero / `^SKIP` / `PORTABILITY_SMOKE_SKIP` under verify-harness → **fail**. |
| INV-3 | Default target `%TEMP%\<GUID>`; reject caller pre-existing path; `-LiteralPath`; **hard-reject** junction/reparse victims; cleanup only invocation-owned marker+path. |
| INV-4 | Mandatory child isolation (`-SkipUserHome` / `CPTK_PORTABILITY_SMOKE=1`); bounded snapshots User HOME + real `%USERPROFILE%\.cursor` plugins/hooks only. |
| INV-10 | Success wording **deterministic-only** in Wave 1 — no “runtime verified” claims. |

### Quick graph (each exactly once)

1. `parse-check-ps1.ps1` — **all tracked** `*.ps1` (plugin/templates/tests included)
2. `validate-project-docs.ps1 -SelfTest`
3. `validate-project-docs.ps1 -ProjectRoot <toolkit-root>`
4. `validate-orchestration.ps1 -SelfTest`
5. `validate-mcp-profiles.ps1 -SelfTest`
6. `validate-living-evals.ps1 -SelfTest`
7. `validate-recovery.ps1 -SelfTest`
8. `scripts/dry-run-strict-hooks.ps1`
9. `templates/hooks/dry-run-strict-hooks.ps1`
10. `test-session-start-context.ps1`
11. `tests/project-doctor/test-secret-leak.ps1`
12. `tests/project-doctor/test-bracket-path.ps1`
13. `tests/project-doctor/test-missing-phase.ps1`

### Full profile

| Entry | Behavior |
|-------|----------|
| `verify-harness -Profile Full` | Quick, then once `smoke-bootstrap -OracleOnly` — no toolkit-root validator repeats inside oracle |
| `smoke-bootstrap` (default) | Self-contained legacy path; may duplicate Quick head; **must not** call `verify-harness` |

Post-copy on copied Full target: living SelfTest, **`F-COPY-REC` always**, MCP default, template dry-run. Orchestration from copy **forbidden**.

### Ownership tests (`tests/portability/test-smoke-target-safety.ps1`)

Pre-existing sentinel rejected; junction hard-reject; default temp cleanup; `-KeepOnFailure`.

### Wave 1 stop gate

No silent skip; no non-owned delete; no HOME/plugins/hooks mutation; three consecutive Full exit 0; `git status` clean after run.

---

## Windows CI (Wave 2)

One unconditional `windows-latest` job; `shell: powershell` (5.1); runs `verify-harness -Profile Full`.

| Required | Forbidden |
|----------|-----------|
| Triggers: `pull_request`, push `main`, `workflow_dispatch` | `paths` / `paths-ignore`, matrix, cache |
| `permissions: contents: read`; actions SHA-pinned | `pull_request_target`, write perms, secrets |
| PR concurrency cancel-in-progress; main not cancelled | Branch protection edits (Human Gate) |
| Stable required-check name; job summary with stages/durations | Claiming runtime/model verified |

Rollout: `workflow_dispatch` → test PR → owner Human Gate for branch protection.

---

## Wave 3 slices (executable: 3A, 3B, 3D only)

| Slice | Content | Out of scope |
|-------|---------|--------------|
| **3A** | Light verification profiles/scope; full triggers + due checkpoint; evidence-backed fixtures | Recovery path changes |
| **3B** | Paired T3 +/- examples; scouts default 0, max 3 (4th justified); one writer | Premium scouts; remove Sol |
| **3D** | Hygiene: `Programms`→`Program`, 12/12 living-eval, stale refs, static vs runtime claims in plugin doc | Stop-hook / HOOK-01 |

**3C recovery shadow** and **HOOK-01** → Waves 4–6 / later contract.

---

## Waves 4–6 (gated — not executable in v2 initial scope)

| Wave | Gate |
|------|------|
| **4** Runtime ownership experiment; shadow shipping manifest; provenance | Stable green CI |
| **5** Fast vs standard A/B; sequential recovery shadow; evidence sidecar | Attributable models + reliable oracle |
| **6** Changed-path planner shadow | p95 > 5 min or quota pressure; ≥20 CI runs; 30–60 same-SHA patches; zero selector misses |

---

## Recommendation matrix (final decisions)

### Models / orchestration

| ID | Decision |
|----|----------|
| MODEL-01 | **MODIFY** — no pin change from published price; availability defect vs perf separate; Fast A/B deferred |
| MODEL-02 | **MODIFY** — capability/independence/cost in manifest/contracts; no third registry |
| MODEL-03 | **ACCEPT** — Sol for real T3; paired +/- examples for trust boundary, public contract, persistence, concurrency |
| MODEL-04 | **DEFER** global sequential recovery; dual-blind for high-risk |
| MODEL-05 | **MODIFY** — scouts default 0; max 3; read-only; one writer |

### Verification / CI

| ID | Decision |
|----|----------|
| VERIFY-01 | **MODIFY** — light vocabulary only |
| VERIFY-02 | **ACCEPT** — full triggers: pre-merge, release, shared config, public contract, unknown impact, flake, explicit request |
| VERIFY-03 | **MODIFY** — remove measured duplication; no cache engine |
| VERIFY-04 | **MODIFY** — one unconditional Windows job first |
| VERIFY-05 | **DEFER** schema churn — toolkit sidecar first |

### Packaging / governance

| ID | Decision |
|----|----------|
| RUNTIME-01 | **MODIFY** — single runtime hook owner until coexistence experiment |
| UPDATE-01 / SOURCE-01 | **DEFER** naive marker; **ACCEPT** light `last_verified` for volatile claims |
| OSS-01 / PORT-01 / ENFORCE-01 | **DEFER** / **REJECT NOW** per research plan |
| ORACLE-01 / SMOKE-01 / CI-01 / PARSE-01 | **ACCEPT** |
| HYGIENE-01 | **ACCEPT** — Wave 3D |

---

## Human Gates (explicit approval required)

- Branch protection / required checks
- Plugin install/remove or real user-profile mutation
- Exact model pin / cost-class change
- Root LICENSE
- commit / push / merge / tag / release / publish
- Strict hooks promotion, auto-update, consumer file deletion

---

## Principal review outcomes (v1 attempt 2)

Two material principal outcomes shaped the executable architecture:

1. **Scope cut:** Wave 3C (recovery shadow/simulator) and HOOK-01 removed from Waves 0–3; dual-blind production recovery unchanged; deferred to Waves 4–6.
2. **Oracle contract hardened:** `verify-harness Full` = Quick + `-OracleOnly` only; standalone smoke self-contained; junction **hard-reject**; `STAGE_OK` fail-closed; `F-COPY-REC` mandatory; deterministic-only success wording (INV-10); concrete Docs Impact YAML per Wave 3 slice.

---

## Blocked contract: toolkit-fast-loop-v1

| Field | Value |
|-------|-------|
| Path | `.cursor/plans/toolkit-fast-loop-v1.plan.md` (gitignored) |
| Status | **BLOCKED** — metadata only |
| Technical completeness | Revision 4 / cycle 4 content is technically complete for Waves 0–3 |
| Block reason | **`cycle: 4`** in plan frontmatter — contract enum allows **`1|2|3` only** (attempt 2 saw invalid cycle, not an open technical gap) |
| Action | Create **`toolkit-fast-loop-v2`** at **cycle 1** with one bounded principal gate; copy architecture from this doc + v1 plan body |

Do **not** resume v1. Do **not** treat BLOCKED as missing design.

---

## Implementation sequence (next contract)

```text
Wave 0 baseline (no writes) → Wave 1 oracle PR → Wave 2 CI PR → Wave 3A → 3B → 3D
```

Verify after Wave 1:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\portability\test-smoke-target-safety.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\verify-harness.ps1 -Profile Quick
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\verify-harness.ps1 -Profile Full
git diff --check
```

---

## Related artifacts

| Artifact | Role |
|----------|------|
| [session-handoff-2026-07-23.md](session-handoff-2026-07-23.md) | Session timeline, git state, risks |
| `.cursor/plans/toolkit-fast-loop-v1.plan.md` | Detailed wave tables (BLOCKED; use for v2 drafting) |
| `project-workflow/continue-chat-prompt.md` | Copy-paste prompt for new implementation chat |
| Advisory `Рекомендация ГПТ про/` | Untracked input only — never normative |
