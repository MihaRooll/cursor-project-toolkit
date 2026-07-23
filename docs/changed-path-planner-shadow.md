# Changed-path verification planner (Wave 6 shadow)

> Shadow-only selector for Quick/Full check IDs from changed paths — **does not run, skip, or gate CI**. Wave 6 **not graduated**.

## For agents

| When | Do |
|------|-----|
| Plan verification from local changes | `scripts/plan-verification.ps1 -Mode worktree [-OutputPath …]` |
| Simulate PR / push / dispatch | `-Mode PR|push|dispatch` (+ `-ChangeSpecJson` for fixtures) |
| Check registry | `shipping/verification-checks.v1.json` |
| Full oracle reference | `scripts/verify-harness.ps1` (13 Quick + 13 Full-oracle stages) |

**Apply**

- Modes: `worktree` (git porcelain `-z`), `PR`, `push`, `dispatch`.
- Gather **staged + unstaged + untracked**; renames → old + new paths (byte/NUL-safe git plumbing or explicit fixture).
- Caller may pass `-ChangeSpecJson` / `-ChangeSpecPath` for SelfTest/fixtures (bypasses git).
- **Conservative Full** when any trigger fires: missing history, merge conflict, parse error, unknown path, workflow/bootstrap/shipping-manifest/planner/plugin mirror/shared contract change, or mode `PR`/`push`/`dispatch`.
- Path-matched Quick subset when conservative Full **not** fired; dependencies expanded from manifest.
- Output: advisory JSON only — `shadow_only=true`, `runs_checks=false`, `gates_ci=false`.
- Atomic `FileMode.CreateNew`; caller-owned or gitignored `.cursor/planner-local/`; reparse rejected; repo-relative paths only.
- `-SelfTest` + `tests/planner/test-plan-verification.ps1`.

**Graduation gates (evidence_pending — not met)**

| Gate | Threshold | Current |
|------|-----------|---------|
| Full p95 | > 5 min | **~2m25s** observed on CI (`29983360670`) — **not eligible** |
| CI runs | ≥ 20 | pending corpus |
| Same-SHA patches | 30–60; median ≥ 25 | pending |
| Selector misses | 0 | required in fixtures |

**Do not**

- Wire planner into `.github/workflows/toolkit-verify.yml` (no `paths`, matrix, conditional jobs).
- Ship planner script/manifest/tests via Essential/Full bootstrap.
- Claim CI time savings or auto-skip checks from shadow output.

## ChangeSpec fixture (SelfTest)

```json
{
  "mode": "worktree",
  "paths": [
    { "path": "docs/README.md", "class": "modified", "staged": true }
  ],
  "flags": { "missing_history": false, "merge_conflict": false, "parse_error": false }
}
```

Path classes: `modified`, `added`, `deleted`, `untracked`, `renamed_old`, `renamed_new`.

## Plan output (summary)

| Field | Meaning |
|-------|---------|
| `recommended_profile` | `Quick` or `Full` |
| `conservative_full` | All 26 stage IDs selected |
| `full_triggers_fired[]` | Why Full was chosen |
| `selected_check_ids[]` | Shadow plan (never executed here) |
| `full_oracle_check_ids[]` | Full oracle reference set |
| `selector_miss` | Must stay `false` in fixtures |
| `promotion_status` | Always `evidence_pending` until gates met |

## Commands

```powershell
scripts/plan-verification.ps1 -SelfTest
tests/planner/test-plan-verification.ps1

scripts/plan-verification.ps1 -Mode worktree -OutputPath .cursor/planner-local/plan.json
scripts/plan-verification.ps1 -Mode PR -ChangeSpecPath tests/planner/fixtures/pr-premerge-full.json
```

## Lifecycle

1. **Shadow (now):** planner + manifest + fixtures; compare to Full oracle offline.
2. **Evidence:** collect p95, CI run count, same-SHA patch stats; zero selector misses.
3. **Human Gate:** no conditional CI until graduation gates + explicit approval (T4).
4. **Production:** separate contract — never auto-promote from shadow JSON.

## Related

- CI gate (unchanged): [ci-toolkit-verify.md](ci-toolkit-verify.md)
- Architecture: [fast-development-harness-plan.md](fast-development-harness-plan.md) Wave 6
- Shipping manifest: [bootstrap-scaffold.md](bootstrap-scaffold.md) Wave 4B

## Checklist

- [ ] After planner edits: `-SelfTest` + `tests/planner/test-plan-verification.ps1`
- [ ] `validate-recovery.ps1 -SelfTest` and other production validators still pass
- [ ] `validate-project-docs.ps1` after doc/map updates
- [ ] Confirm workflow still unconditional Full (~2m25s)
