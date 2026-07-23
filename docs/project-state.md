# Project state — cursor-project-toolkit

> Toolkit repo phase tracker.

## For agents

**When to read:** session-start hook may inject phase summary; orchestration wave work; fast-loop v2 progress.

**Apply:** this file tracks **toolkit** evolution, not consumer products. Normative architecture: [fast-development-harness-plan.md](fast-development-harness-plan.md).

---

## phase

`toolkit-fast-loop-v2` — Waves 0–3 implemented **locally** (Quick/Full oracle, verification policy, T3/scout policy, hygiene). CI workflow exists on disk; **not** claiming live GitHub green, branch protection, or runtime/plugin coexistence verified.

## milestones

| Milestone | Status | Notes |
|-----------|--------|-------|
| Wave 1–4b harness capability stack | done | orchestration, living docs, MCP, strict hooks, portability |
| Wave 5 delegation-first | done | Main never product-writes T0–T3 |
| Fast-development research (3×5 audit) | done | [session-handoff-2026-07-23.md](session-handoff-2026-07-23.md) |
| Architecture SSOT | done | [fast-development-harness-plan.md](fast-development-harness-plan.md) |
| toolkit-fast-loop-v1 normative plan | blocked | metadata only — do not resume |
| toolkit-fast-loop-v2 contract | in_progress | Waves 0–3 slices landing |
| Quick/Full oracle (`verify-harness`) | done | local Quick + Full exit 0; not runtime proof |
| Wave 2 CI workflow (on-disk) | done | `.github/workflows/toolkit-verify.yml`; activation/protection = Human Gate |
| Wave 3A verification profiles | done | contracts + orchestration doc |
| Wave 3B T3 boundary + scout policy | done | tier-rubric + operational-orchestrator |
| Wave 3D hygiene | in_progress | Program paths, living-eval 12/12, static vs runtime plugin claims |
| Live CI + branch protection | pending | Human Gate — do not claim green workflow |
| Marketplace plugin publish | pending | human gate |

## next_checks

- [ ] After docs-touching slices: `scripts\validate-project-docs.ps1 -ProjectRoot .`
- [ ] Local completion: `scripts\verify-harness.ps1 -Profile Quick`
- [ ] INV-7 checkpoint (same-SHA): `scripts\verify-harness.ps1 -Profile Full` — local evidence only until required CI active
- [ ] Before ship: `git diff --check`; do not claim live CI/protection without Human Gate signoff

## toolchain_notes

Windows PowerShell 5.1 for hooks/doctor/smoke; git required.
