# Evidence sidecar and Fast A/B protocol (Wave 5A)

> Toolkit-only evidence rows + deterministic A/B plan generator. Status/diff and planning only — never apply pins, cost class, or strict-hook promotion.

## For agents

| When | Do |
|------|-----|
| Log one bounded task outcome | `scripts/write-evidence-sidecar.ps1` with validated JSON row |
| Validate sidecar JSON | `scripts/validate-evidence-sidecar.ps1 -InputPath <file>` |
| Plan Fast vs standard A/B | `scripts/ab-protocol.ps1 -ContractId … -TaskId … -Seed <non-zero>` |
| Schema | `tests/orchestration/evidence-schema.json` |

**Apply**

- One sidecar file per **contract + run** under caller-owned path or gitignored `.cursor/evidence-local/`.
- Writer: atomic create, reject pre-existing, reparse ancestor checks; console prints `sidecar=output=invocation-owned` only.
- Row fields: `contract_id`, `task_id`, roles/models (nullable/`unknown`), timing, `verification_profile`, `cycles`, `check_outcomes[]`, `first_verify_pass`, `protocol_violations[]`, `fast_mode_used`, `premium_calls`, `promotion_status`.
- Writer accepts `promotion_status=evidence_pending` only until corpus thresholds (6–10 comparable tasks + quality/saving gates).
- A/B planner: seeded AB/BA sequences, **one varied role**, same `oracle_check_ids`, fresh-context/isolated-branch metadata; **no live model calls**; **no pin/cost changes**.
- `availability_defect` is tracked separately from Fast perf evaluation (MODEL-01).
- `-SelfTest` on all three scripts; integration: `tests/orchestration/evidence/test-evidence-sidecar.ps1`.

**Do not**

- Ship schema/scripts in Essential bootstrap or plugin mirrors.
- Store raw prompts, logs, username/hostname, absolute/private paths, email, secrets, plugin inventory.
- Auto-promote Fast default or strict hooks from sidecar rows alone.
- Treat sidecar as platform enforcement.

## Sidecar row (summary)

| Field | Meaning |
|-------|---------|
| `contract_id` / `task_id` | Stable contract + bounded task ids |
| `intended_role` / `actual_role` | Planned vs observed role (`null` or `unknown` ok) |
| `intended_model` / `actual_model` | Planned vs observed slug (`null` or `unknown` ok) |
| `wall_clock` / `verification_seconds` | Timing |
| `verification_profile` | `targeted` \| `affected` \| `checkpoint` \| `full` \| `quick` |
| `check_outcomes[]` | `{ check_id, outcome: pass\|fail\|skip\|error }` |
| `cycles` / `first_verify_pass` | Rework + first-pass oracle |
| `protocol_violations[]` | Bounded codes; empty when clean |
| `fast_mode_used` / `premium_calls` | Fast + premium usage counters |
| `promotion_status` | Writer: `evidence_pending` only |

## A/B plan (summary)

| Field | Meaning |
|-------|---------|
| `seed` | Deterministic plan generation (non-zero) |
| `oracle_check_ids` | Shared check IDs for both arms |
| `varied_role` | Single role that differs between A/B mode |
| `arms[]` | AB and BA orderings with `arm_A` / `arm_B` specs |
| `promotion_thresholds` | min 6 / max 10 comparable tasks + quality/saving gates |
| `worktree` | `fresh_context`, `isolated_branch`, `run_fingerprint` (relative ids only) |

## Commands

```powershell
scripts/validate-evidence-sidecar.ps1 -SelfTest
scripts/write-evidence-sidecar.ps1 -SelfTest
scripts/ab-protocol.ps1 -SelfTest

tests/orchestration/evidence/test-evidence-sidecar.ps1

scripts/ab-protocol.ps1 -ContractId toolkit-fast-loop-v3 -TaskId slice5a-sample -Seed 42 `
  -VariedRole implementer -CheckIds Q-ORCH-ST,Q-PARSE
```

## Related

- Shadow corpus (legacy fields): [orchestration-evidence.md](orchestration-evidence.md)
- Strict hook promotion: [harness-evidence-and-enforcement.md](harness-evidence-and-enforcement.md)
- Architecture gate: [fast-development-harness-plan.md](fast-development-harness-plan.md) Wave 5

## Checklist

- [ ] After schema/script edits: all three `-SelfTest` + integration test
- [ ] `validate-orchestration.ps1 -SelfTest` still passes (toolkit-only surface)
- [ ] Essential/bootstrap arrays exclude sidecar paths
- [ ] `validate-project-docs.ps1` after doc/map updates
