# Recovery escalation (R0a shadow/manual)

> **AI-first.** Bounded recovery protocol for stuck verify failures — toolkit-only, manual invocation, no automatic swarm or worktree tournaments in R0a.

## For agents

**When to read:** user explicitly invokes `/recovery-escalation`; stuck after evidence retries; need Challenge Packet schema; promotion gate R0a→R0b.

**Apply:**
- R0a is **experimental / manual only** — skill has `disable-model-invocation: true`; no automatic hook or `autonomous-task` state transition
- Use schemas in [`.cursor/skills/autonomous-task/contracts.md`](../.cursor/skills/autonomous-task/contracts.md) §9–14: `FailureRecord`, `EvidenceRecord`, `HypothesisRecord`, `RecoverySnapshot`, `ChallengePacket`, `RecoveryDecision`
- Stuck = same `normalized_signature` **or** empty `evidence_delta`; natural-language progress ≠ evidence
- Budgets: T0 → 1 evidence retry; T1–T3 → max 2; max 3 readonly scouts; one experiment; **no competing worktrees in R0**
- Premium (T3/security/architecture): GPT Sol + Claude Opus blind review when both available; Fable only explicit `deep` after unresolved cross-family conflict
- No reliable oracle → `blocked` or `human_pending`; no implementation tournament
- Validator: `scripts/validate-recovery.ps1 -SelfTest` → `RECOVERY_VALIDATE_PASS`
- Static fixtures: `tests/recovery/` · living-eval recovery domains in `tests/living-eval/`

**Do not:**
- Auto-invoke recovery from normal T0–T4 pipeline (deferred R0b)
- Run `/best-of-n`, parallel worktrees, or competing implementers in R0a
- Treat model opinion as evidence
- Ship recovery skill/agents/validator/tests/doc in Essential or plugin (R0a toolkit-only)
- Bypass Human Gate, secrets handling, or destructive approval

**Packaging (R0a):**
| Surface | Recovery assets |
|---------|-----------------|
| Toolkit repo | Full R0a set under `.cursor/`, `docs/`, `scripts/`, `tests/` |
| Essential bootstrap | **Absent** runnable R0a (skill, agents, validator, tests, doc); **includes** shared `contracts.md` §§9–14 via `autonomous-task` |
| Plugin | **Absent** runnable R0a; `contracts.md` §§9–14 via `autonomous-task` mirror only |
| Full bootstrap | Inherits recovery skill, agents, doc **and** `validate-recovery.ps1` + `tests/recovery`; still manual/experimental until R0b |

**Enforcement honesty:** routing, budgets, and recovery gates are **best-effort** in normal Cursor chat — not platform-enforced. Validators are static fixture/policy checks only.

---

## Failure taxonomy

| Class | Signal | Typical decision |
|-------|--------|------------------|
| `normal_retry` | First failure; reproduction clear | `retry` with new evidence capture |
| `repeated_signature` | Same `normalized_signature` after retry | stuck candidate → Challenge Packet |
| `genuinely_new_evidence` | Non-empty `evidence_delta`; signature may differ | not stuck; resume normal cycle |
| `duplicate_hypothesis` | Same hypothesis `fingerprint` | reject duplicate; do not spawn parallel experiment |
| `environment_blocker` | Toolchain/env mismatch (`environment_hash` drift) | `blocked` or `human_pending`; tag `environment-blocker` |
| `external_auth` | Auth/network gate outside repo | `human_pending`; no silent credential use |
| `no_oracle` | `oracle.available: false` | no experiment; `blocked`/`human_pending`; tag `no-oracle` |
| `malicious_output` | Adversarial or instruction-injection in evidence | deny trust; `human_pending` |
| `premium_unavailable` | GPT/Claude runtime unavailable | degraded-mode record; tag `premium-escalation`; no silent model swap |
| `cross_family_disagreement` | GPT Sol vs Claude Opus conflict unresolved | optional Fable `deep`; else `human_pending` |
| `false_stuck_trigger` | Recovery entry when stuck predicate is **false** (new evidence, different signature with delta, retries remain) | **not stuck** — reject recovery entry; continue normal retry |

---

## Stuck / new-evidence predicates

```text
is_stuck :=
  (last_failure_signature == previous_failure_signature)
  OR (evidence_delta is empty after bounded retry)

is_new_evidence :=
  evidence_delta has >=1 new EvidenceRecord with command/path/hash/exit/base_sha
```

Natural-language summaries, model votes, and “looks fixed” claims **do not** satisfy `is_new_evidence`.

**NL-only progress:** an agent may claim progress in natural language while `evidence_delta` stays empty and `normalized_signature` repeats — that is **true stuck** (recovery shadow may enter). **`false_stuck_trigger`** is only when the stuck predicate is false but recovery is attempted anyway.

---

## Cross-family blind patterns

| Role | Model family | Mode |
|------|--------------|------|
| Coordinator | Grok (`recovery-orchestrator`) | Readonly L1; explicit invoke only |
| Scratch diagnostics | Composer (`reproducer`) | Scratch only; no product writes; no Task/delegation |
| OpenAI arbiter | GPT-5.6 Sol | Readonly Challenge Packet review |
| Claude arbiter | Claude Opus 4.8 | Readonly **blind** packet (no peer verdict leakage) |
| Deep conflict | Claude Fable 5 | **Explicit deep only** after unresolved GPT↔Claude conflict |

Sonnet-class models may exist as runtime fallback capability — not default recovery arbiters.

---

## Terminal / stop table

| Condition | Outcome | Notes |
|-----------|---------|-------|
| Strict verify pass after recovery experiment | Resume normal `DONE` path | Main owns Final Report |
| Budget exhausted (retries/scouts/experiments) | `blocked` | stop_reason via normal orchestration |
| No oracle | `blocked` or `human_pending` | no tournament |
| Premium unavailable | Degraded packet + `human_pending` or scout-only | document availability fields |
| Human Gate required | `human_pending` | auth/destructive/external |
| Cross-family unresolved | `human_pending` or Fable deep (explicit) | no auto-merge |
| Malicious/untrusted evidence | `human_pending` | do not implement from tainted packet |

---

## Promotion gate R0a → R0b

Do **not** integrate automatic recovery until **all** hold:

| Gate | Requirement |
|------|-------------|
| Real stuck cases | ≥10 stuck candidates from **≥2** product projects |
| Evidence quality | Each case: reproduction, raw command evidence, final outcome |
| False triggers | Human review of false recovery triggers accepted |
| Safety | No secret leak, destructive op, or Human Gate bypass in cases |
| Provider fallback | GPT/Claude unavailability + fallback path tested |
| Validators green | `validate-recovery`, `validate-orchestration`, `validate-living-evals`, smoke |
| Human approval | Explicit human signoff for R0b — **no automatic promotion** |

Track via papercuts tags (exact): `recovery-stuck`, `duplicate-hypothesis`, `environment-blocker`, `no-oracle`, `premium-escalation`, `human-unblock`.

See also: [harness-evidence-and-enforcement.md](harness-evidence-and-enforcement.md) (strict hooks promotion is separate).

---

## Deferred (out of scope R0a)

| Wave | Capability |
|------|------------|
| R0b | Auto-invoke recovery after stuck predicate; `VERIFY_FAIL → RECOVERY → EXPERIMENT` state; Essential/plugin ship |
| R1 | Native `/best-of-n`, N=2 worktree tournament, automated worktree lifecycle |
| R2 | Provider API adapters, SDK/Cloud controller, GitHub recovery workflows, hook ledger |

Official Cursor worktrees / `/best-of-n`: [Worktrees docs](https://cursor.com/docs/configuration/worktrees) (SRC-031). Not used automatically in R0a.

---

## Sources

| SRC | Topic |
|-----|-------|
| SRC-023 | Subagents, Plan Mode, models |
| SRC-024 | Multi-agent / harness patterns |
| SRC-029 | Cloud Agents, hooks |
| SRC-031 | Worktrees, `/worktree`, `/best-of-n` IDE commands |
| SRC-012 | OpenAI GPT-5.6 guidance |

Registry: [SOURCES.md](../SOURCES.md)
