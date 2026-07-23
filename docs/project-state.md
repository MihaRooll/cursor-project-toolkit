# Project state — cursor-project-toolkit

> Toolkit repo phase tracker.

## For agents

**When to read:** session-start hook may inject phase summary; orchestration wave work; fast-loop v3 / SHIP-V2 progress.

**Apply:** this file tracks **toolkit** evolution, not consumer products. Normative architecture: [fast-development-harness-plan.md](fast-development-harness-plan.md).

---

## phase

`toolkit-fast-loop-v3` — SHIP-V2 close. Waves 0–3 implemented locally. **Wave 4 gate:** live `toolkit-verify` green on GitHub (see ship block); branch protection active on `main`. **Wave 4A runtime experiment:** Human-Gated trials complete; profile restored. **Waves 4A/4B/4C done.** **Wave 5A done; Wave 5B (in progress):** sequential recovery shadow simulator. Remaining Wave 5+ / Waves 6 pending.

## ship (open PR)

| Item | Value |
|------|-------|
| PR | [#4](https://github.com/MihaRooll/cursor-project-toolkit/pull/4) — **open**, not merged |
| CI SHA | `5f8eb916d51c9394f1183c8976c3be3ba0112590` |
| toolkit-verify run | `29983360670` — passed, 2m25s |
| `main` protection | strict required status context `toolkit-verify`; force-push and branch deletion disabled |

## milestones

| Milestone | Status | Notes |
|-----------|--------|-------|
| Wave 1–4b harness capability stack | done | orchestration, living docs, MCP, strict hooks, portability |
| Wave 5 delegation-first | done | Main never product-writes T0–T3 |
| Fast-development research (3×5 audit) | done | [session-handoff-2026-07-23.md](session-handoff-2026-07-23.md) |
| Architecture SSOT | done | [fast-development-harness-plan.md](fast-development-harness-plan.md) |
| toolkit-fast-loop-v1 normative plan | blocked | metadata only — do not resume |
| toolkit-fast-loop-v2 contract | done | Waves 0–3 slices landed locally |
| toolkit-fast-loop-v3 / SHIP-V2 | in_progress | Wave 4 CI gate green; PR #4 open; Waves 4–6 pending |
| Quick/Full oracle (`verify-harness`) | done | local Quick + Full exit 0 |
| Wave 2 CI workflow (on-disk) | done | `.github/workflows/toolkit-verify.yml` |
| Wave 3A verification profiles | done | contracts + orchestration doc |
| Wave 3B T3 boundary + scout policy | done | tier-rubric + operational-orchestrator |
| Wave 3D hygiene | done | Program paths, living-eval 12/12, static vs runtime plugin claims |
| Wave 4 CI gate (live GitHub) | done | run `29983360670` on SHA `5f8eb916…`; required check on `main` |
| Waves 4–6 implementation | pending | Wave 4A/4B/4C done; remaining Wave 4+ / 5–6 gated work |
| Runtime coexistence protocol (Wave 4A) | done | tooling + TestOnly + live-first rollback |
| Wave 4A plugin-only runtime (Human Gate) | done | Cursor 3.12.17; `runtime_verified=true`; profile plugin removed post-trial |
| Wave 4A combined runtime | done (negative) | both sources recorded → `combined_unsupported`; Essential retained as workspace owner |
| Wave 4B shadow shipping manifest | done | `shipping/manifest.v1.json` + validator vs live bootstrap arrays; bootstrap still array-driven |
| Wave 4C harness provenance collector | done | `schemas/provenance.v1.json` + `collect-provenance.ps1` + doctor local drift; status/diff only |
| Wave 5A evidence sidecar + A/B protocol | done | sidecar writer/validator + `ab-protocol.ps1`; toolkit-only; promotion evidence_pending |
| Wave 5B sequential recovery shadow | in_progress | two-phase Commit/Reveal; `validate-recovery-shadow.ps1`; toolkit-only `tests/recovery-shadow/`; production R0a unchanged |
| Runtime coexistence in Cursor IDE (combined) | unsupported | defer until later coexistence design |
| Marketplace plugin publish | pending | human gate |

## next_checks

- [ ] After docs-touching slices: `scripts\validate-project-docs.ps1 -ProjectRoot .`
- [ ] Local completion: `scripts\verify-harness.ps1 -Profile Quick`
- [ ] INV-7 checkpoint (same-SHA): `scripts\verify-harness.ps1 -Profile Full` — align local SHA with PR head before merge
- [ ] Before merge: confirm PR #4 head matches green CI SHA
- [ ] Wave 4B: after bootstrap array edits run `scripts\validate-shipping-manifest.ps1` (shadow manifest sync)
- [ ] Wave 4C: after provenance edits run `scripts\collect-provenance.ps1 -SelfTest` and `tests\provenance\test-collect-provenance.ps1`
- [ ] Wave 5A: after sidecar/A/B edits run `scripts\validate-evidence-sidecar.ps1 -SelfTest`, `scripts\write-evidence-sidecar.ps1 -SelfTest`, `scripts\ab-protocol.ps1 -SelfTest`, and `tests\orchestration\evidence\test-evidence-sidecar.ps1`
- [ ] Wave 5B: after shadow edits run `scripts\recovery-shadow.ps1 -SelfTest`, `scripts\validate-recovery-shadow.ps1 -SelfTest`, and `tests\recovery-shadow\test-recovery-shadow.ps1`
- [ ] Waves 4–6: follow [fast-development-harness-plan.md](fast-development-harness-plan.md)

## toolchain_notes

Windows PowerShell 5.1 for hooks/doctor/smoke; git required.
