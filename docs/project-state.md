# Project state — cursor-project-toolkit

> Toolkit repo phase tracker.

## For agents

**When to read:** session-start hook may inject phase summary; orchestration wave work; fast-loop v3 / SHIP-V2 progress.

**Apply:** this file tracks **toolkit** evolution, not consumer products. Normative architecture: [fast-development-harness-plan.md](fast-development-harness-plan.md).

---

## phase

`toolkit-fast-loop-v3` — SHIP-V2 close. Waves 0–3 implemented locally. **Wave 4 gate:** live `toolkit-verify` green on GitHub (see ship block); branch protection active on `main`. **Waves 4–6** implementation pending. Runtime/plugin coexistence **not** verified.

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
| Waves 4–6 implementation | pending | beyond CI gate — not started |
| Runtime coexistence protocol (Wave 4A) | implemented | transactional backup + TestOnly SelfTest; `runtime_verified` requires RealProfile + IdeAttested + evidence_complete |
| Runtime coexistence in Cursor IDE | pending | external IDE reload + full phase order — not verified |
| Marketplace plugin publish | pending | human gate |

## next_checks

- [ ] After docs-touching slices: `scripts\validate-project-docs.ps1 -ProjectRoot .`
- [ ] Local completion: `scripts\verify-harness.ps1 -Profile Quick`
- [ ] INV-7 checkpoint (same-SHA): `scripts\verify-harness.ps1 -Profile Full` — align local SHA with PR head before merge
- [ ] Before merge: confirm PR #4 head matches green CI SHA; do not claim runtime coexistence without evidence
- [ ] Waves 4–6: follow [fast-development-harness-plan.md](fast-development-harness-plan.md)

## toolchain_notes

Windows PowerShell 5.1 for hooks/doctor/smoke; git required.
