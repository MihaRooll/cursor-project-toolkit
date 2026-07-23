# Sequential recovery shadow (Wave 5B)

> Toolkit-only sequential recovery experiment simulator — metadata + explicit reliable oracle only. Production R0a dual-blind recovery **unchanged**.

## For agents

| When | Do |
|------|-----|
| Commit phase (first verdict + commitment) | `scripts/recovery-shadow.ps1 -Action Commit -InputPath <candidate.json> [-OutputPath …]` |
| Reveal phase (second verdict + score) | `scripts/recovery-shadow.ps1 -Action Reveal -CommitmentPath <commitment.json> -SecondVerdictPath <verdict.json>` or `-SecondVerdictJson '<json>'` |
| Validate shadow JSON | `scripts/validate-recovery-shadow.ps1 -InputPath … -SchemaKind commit_input\|commitment_record\|final_record` |
| Schema / thresholds | `tests/recovery-shadow/shadow-schema.json` |
| Production recovery protocol | [recovery-escalation.md](recovery-escalation.md) (R0a manual) |

**Apply**

- **Two-phase API only:** Commit input **must not** include `second_verdict`. Reveal is a separate action after commitment exists.
- Oracle eligibility: explicit `oracle.available=true` **and** `oracle.reliable=true` **and** nonempty `check_id`; omitted `reliable`/`available` = ineligible (schema + runtime).
- **Exclude** when oracle ineligible or `risk_tags` include: `no_oracle`, `high_consequence`, `security`, `public_contract`, `persistent`, `irreversible`.
- Protocol order: **first verdict** → **commitment hash + sequence proof** (CreateNew) → **second verdict reveal** → **deterministic score**.
- Recompute/verify `commitment_hash` and `sequence_proof` on Reveal (includes `before_second_reveal=true` and `live_model_calls=false` in seeds); tamper/reorder/replay fail.
- **One-time Reveal:** atomic `{commitment}.reveal.lock` marker (CreateNew) consumed per commitment path; replay rejected even with alternate `-OutputPath`; marker rolled back if final CreateNew fails.
- **Critical miss** (`second_call` in `experiment|premium` but second verdict `blocked|human_pending`) **stops** experiment.
- Output: caller-owned path or gitignored `.cursor/recovery-shadow-local/`; `FileMode.CreateNew`; duplicate/reparse rejected; reveal lock sibling to commitment file.
- `-SelfTest` on both shadow scripts + `tests/recovery-shadow/test-recovery-shadow.ps1`.

**Do not**

- Change production dual-blind recovery agents/skill flow or `validate-recovery.ps1` shadow deps.
- One-shot input with both commitment and second verdict.
- Ship shadow scripts/schema/tests in Essential or Full bootstrap copies.
- Make live model calls or pin/cost changes.

## Candidate metadata (Commit input)

| Field | Meaning |
|-------|---------|
| `candidate_id` | Stable shadow candidate id |
| `consumer_repo` | Bootstrapped product repo name |
| `tier` | T0–T4 at stuck boundary |
| `oracle` | `{ available, reliable, check_id }` — all three required |
| `risk_tags[]` | Exclusion tags (see Apply) |
| `first_verdict` | `{ family, decision }` — first family verdict |
| `second_call_decision` | Decision **before** second verdict reveal |

**Forbidden on Commit input:** `second_verdict` (use Reveal action).

## Record types

| `record_type` | Phase | Key fields |
|---------------|-------|------------|
| `commitment` | After Commit | `first_verdict`, `commitment.{commitment_hash,sequence_proof,before_second_reveal}` |
| `final` | After Reveal | above + `second_verdict`, `score`, `protocol_sequence` |

## Commands

```powershell
scripts/recovery-shadow.ps1 -SelfTest
scripts/validate-recovery-shadow.ps1 -SelfTest
tests/recovery-shadow/test-recovery-shadow.ps1

# Two-phase flow
scripts/recovery-shadow.ps1 -Action Commit -InputPath candidate.json -OutputPath commitment.json
scripts/recovery-shadow.ps1 -Action Reveal -CommitmentPath commitment.json `
  -SecondVerdictJson '{"family":"claude","decision":"scout"}' -OutputPath final.json
```

## Related

- R0a production recovery: [recovery-escalation.md](recovery-escalation.md)
- Evidence sidecar (Wave 5A): [evidence-sidecar-ab-protocol.md](evidence-sidecar-ab-protocol.md)
- Architecture: [fast-development-harness-plan.md](fast-development-harness-plan.md) Wave 5

## Checklist

- [ ] After shadow edits: both `-SelfTest` + `tests/recovery-shadow/test-recovery-shadow.ps1`
- [ ] `validate-recovery.ps1 -SelfTest` still passes (no shadow coupling)
- [ ] Essential/bootstrap exclude shadow scripts and `tests/recovery-shadow/`
- [ ] `validate-project-docs.ps1` after doc/map updates
