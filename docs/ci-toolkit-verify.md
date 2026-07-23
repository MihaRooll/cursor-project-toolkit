# CI — toolkit-verify (Windows)

> **AI-first.** Unconditional GitHub Actions gate for the toolkit harness oracle.

## For agents

**When to read:** before changing `.github/workflows/toolkit-verify.yml`, CI rollout, or interpreting green/red required checks.

**Apply:** one job `toolkit-verify` on `windows-latest`; PowerShell 5.1 default shell; runs `scripts/verify-harness.ps1 -Profile Full`. Triggers: `pull_request`, push `main`, `workflow_dispatch`. Job summary lists `STAGE_OK` stages and wall clock — deterministic static/smoke only.

**Do not:** add `paths`/`paths-ignore`, matrix, cache, secrets, deploy, conditional jobs, `pull_request_target`, write permissions, or claim runtime/model/plugin proof from this workflow. Branch protection is Human Gate (T4).

---

## Workflow contract

| Item | Value |
|------|-------|
| File | `.github/workflows/toolkit-verify.yml` |
| Check name | `toolkit-verify` (stable job name) |
| Runner | `windows-latest` |
| Shell | `powershell` (5.1) |
| Command | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\verify-harness.ps1 -Profile Full` |
| Permissions | `contents: read` |
| Checkout | `actions/checkout@v4.2.2` SHA-pinned; `persist-credentials: false` |

## Concurrency

| Ref | Behavior |
|-----|----------|
| PR branches | `cancel-in-progress: true` (same workflow group) |
| `main` | `cancel-in-progress: false` |

## Deterministic vs runtime boundary

| Proven in CI | **Not** proven |
|--------------|----------------|
| Quick static graph (13 checks once) + Full oracle smoke | Cursor IDE runtime, model availability, plugin install, live hooks |
| `STAGE_OK` stage set equality, fail-closed skips | Branch protection status (Human Gate) |

Job summary repeats this boundary; success line must stay `VERIFY_HARNESS_PASS` wording from verify-harness (INV-10).

## Done evidence (INV-7)

| Phase | Requirement |
|-------|-------------|
| Until required CI is **active** | Same-SHA local `verify-harness -Profile Full` (exit 0) unless explicit human deferral |
| After Wave 2 green workflow | Green `toolkit-verify` on the target SHA **may** satisfy the pre-protection checkpoint |
| Always | Report branch **protection status** (enabled/disabled, required checks) — protection edits remain Human Gate (T4) |

Green CI does **not** replace protection signoff; it only may satisfy the oracle checkpoint before protection is configured.

## Rollout (Human Gate)

1. Push workflow to remote (owner approval).
2. `workflow_dispatch` on a test branch or PR.
3. Confirm green SHA + job summary stages; record protection status.
4. Owner enables branch protection required check `toolkit-verify` (T4 — not automated here).

## Local equivalent

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\verify-harness.ps1 -Profile Full
```

Use until required CI is active; then prefer green `toolkit-verify` on the same SHA for checkpoint evidence (INV-7).

---

## Sources

- [Security hardening for GitHub Actions](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions) — SRC-032
- [actions/checkout v4.2.2](https://github.com/actions/checkout/releases/tag/v4.2.2) — SRC-032
