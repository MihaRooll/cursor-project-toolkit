# Project state — cursor-project-toolkit

> Toolkit repo phase tracker.

## For agents

**When to read:** session-start hook may inject phase summary; post-implementation continuation; PR #4 merge/evidence work.

**Apply:** this file tracks **toolkit** evolution, not consumer products. Normative architecture: [fast-development-harness-plan.md](fast-development-harness-plan.md).

**Same-SHA completion:** do **not** treat any SHA embedded in this file as authoritative for merge readiness. After final CI on PR head, verify the live required check [`toolkit-verify`](https://github.com/MihaRooll/cursor-project-toolkit/pull/4) on GitHub — historical green runs are observations only.

---

## phase

`toolkit-fast-loop-v3` — SHIP-V2 close. **Waves 0–6 tooling/runtime implementation done** locally (oracle, CI workflow, shipping manifest, provenance, evidence sidecar/A-B, recovery shadow, changed-path planner shadow). **Graduation corpora** remain **evidence_pending**: planner promotion + conditional CI, marketplace plugin publish, strict-hook promotion beyond local evidence.

## ship (open PR)

| Item | Value |
|------|-------|
| PR | [#4](https://github.com/MihaRooll/cursor-project-toolkit/pull/4) — **open**, not merged |
| Required check | `toolkit-verify` on **PR head** (authoritative same-SHA completion — verify on GitHub after final CI) |
| PR head observation | SHA `9b684cc773468571c5efc4185c686f52d50aaee2`; CI run `29994496765` success — verify live on GitHub before merge |
| Earlier observation | run `29983360670` ~2m25s on older SHA — historical only |
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
| toolkit-fast-loop-v3 / SHIP-V2 implementation | done | Waves 0–6 tooling/runtime on disk; graduation corpora pending |
| Quick/Full oracle (`verify-harness`) | done | local Quick + Full exit 0 |
| Wave 2 CI workflow (on-disk) | done | `.github/workflows/toolkit-verify.yml` |
| Wave 3A verification profiles | done | contracts + orchestration doc |
| Wave 3B T3 boundary + scout policy | done | tier-rubric + operational-orchestrator |
| Wave 3D hygiene | done | Program paths, living-eval 12/12, static vs runtime plugin claims |
| Wave 4 CI gate (live GitHub) | done | required check active on `main`; verify PR head after CI |
| Runtime coexistence protocol (Wave 4A) | done | tooling + TestOnly + live-first rollback |
| Wave 4A plugin-only runtime (Human Gate) | done | Cursor 3.12.17; `runtime_verified=true`; profile plugin removed post-trial |
| Wave 4A combined runtime | done (negative) | both sources recorded → `combined_unsupported`; Essential retained as workspace owner |
| Wave 4B shadow shipping manifest | done | `shipping/manifest.v1.json` + validator vs live bootstrap arrays |
| Wave 4C harness provenance collector | done | `schemas/provenance.v1.json` + `collect-provenance.ps1` + doctor local drift |
| Wave 5A evidence sidecar + A/B protocol | done | sidecar writer/validator + `ab-protocol.ps1`; toolkit-only; promotion evidence_pending |
| Wave 5B sequential recovery shadow | done | two-phase Commit/Reveal; validate-recovery-shadow; toolkit-only tests/recovery-shadow/ |
| Wave 6 changed-path planner shadow | done | plan-verification.ps1 + verification-checks.v1.json; execution shipped; promotion evidence_pending |
| Runtime coexistence in Cursor IDE (combined) | unsupported | defer until later coexistence design |
| Marketplace plugin publish | evidence_pending | human gate |
| Planner graduation + conditional CI | evidence_pending | gates in verification-checks.v1.json; Full ~2m25s below p95 threshold |

## next_checks

- [ ] Next chat: copy prompt from [project-workflow/continue-chat-prompt.md](../project-workflow/continue-chat-prompt.md); read [session-handoff-2026-07-23.md](session-handoff-2026-07-23.md)
- [ ] After docs-touching slices: `scripts\validate-project-docs.ps1 -ProjectRoot .`
- [ ] Local completion: `scripts\verify-harness.ps1 -Profile Quick`
- [ ] INV-7 checkpoint (same-SHA): `scripts\verify-harness.ps1 -Profile Full` — then confirm PR #4 head green on GitHub
- [ ] Before merge: verify live `toolkit-verify` on PR head (not a SHA frozen in this doc)
- [ ] Wave 4B: after bootstrap array edits run `scripts\validate-shipping-manifest.ps1`
- [ ] Wave 4C: after provenance edits run `scripts\collect-provenance.ps1 -SelfTest` and `tests\provenance\test-collect-provenance.ps1`
- [ ] Wave 5A: after sidecar/A/B edits run evidence sidecar SelfTests + `tests\orchestration\evidence\test-evidence-sidecar.ps1`
- [ ] Wave 5B: after shadow edits run recovery-shadow SelfTests + `tests\recovery-shadow\test-recovery-shadow.ps1`
- [ ] Wave 6: after planner edits run `scripts\plan-verification.ps1 -SelfTest` and `tests\planner\test-plan-verification.ps1`

## toolchain_notes

Windows PowerShell 5.1 for hooks/doctor/smoke; git required.
