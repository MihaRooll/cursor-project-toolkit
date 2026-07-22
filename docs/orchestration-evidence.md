# Orchestration shadow evidence

> **AI-first.** Toolkit-only schema for logging delegation-first routing outcomes across consumer repos. **Not** Essential bootstrap surface. **No strict-hook auto-promotion.**

## For agents

**When to read:** collecting wave eval data; interpreting `tests/orchestration/evidence-schema.json`; deciding whether routing policy needs revision.

**Apply:**

- Log 10–20 real change/build/fix tasks across **≥2** bootstrapped consumer repos (see [harness-consumers.md](harness-consumers.md)).
- One row per bounded task; schema: `tests/orchestration/evidence-schema.json`.
- Required fields: `tier`, `wall_clock`, `model_role_calls`, `first_verify_pass`, `cycles`, `main_product_writes`, `false_escalation`.
- Optional: `contract_id`, `consumer_repo`, `captured_at`.
- Expect `main_product_writes=0` for T0–T3 (Main never product-writes).
- Store rows in toolkit-only corpus (not product root); never write `_v_*.txt` or temp evidence in product root.
- Promotion to strict hooks remains separate — see [harness-evidence-and-enforcement.md](harness-evidence-and-enforcement.md); **never auto-enable** from this schema.

**Do not:**

- Ship `evidence-schema.json` or this doc in Essential bootstrap.
- Treat shadow rows as platform enforcement or hook triggers.
- Auto-promote strict hooks from orchestration evidence alone.

---

## Field meanings

| Field | Meaning |
|-------|---------|
| `tier` | Rubric tier at dispatch (T0–T4) |
| `wall_clock` | End-to-end seconds for bounded workflow |
| `model_role_calls` | Role/model invocations (`implementer` → `composer-2.5-fast`, etc.) |
| `first_verify_pass` | First verification pass without rework |
| `cycles` | Implement/review/verify rework cycles (max 3) |
| `main_product_writes` | Main edits to owned product paths (expect 0 T0–T3) |
| `false_escalation` | Tier raised without rubric evidence |

## Example row

```json
{
  "contract_id": "fix-readme-typo",
  "consumer_repo": "TG_BOT_PRO",
  "captured_at": "2026-07-22T12:00:00Z",
  "tier": "T0",
  "wall_clock": 95,
  "model_role_calls": [
    { "role": "implementer", "model": "composer-2.5-fast", "count": 1 }
  ],
  "first_verify_pass": true,
  "cycles": 0,
  "main_product_writes": 0,
  "false_escalation": false
}
```

## Validator

Toolkit-only: `scripts/validate-orchestration.ps1` asserts schema required fields and that this doc + schema are **absent** from Essential `$mustExist` / bootstrap ship lists.

## Related

- Routing policy: [autonomous-agent-orchestration.md](autonomous-agent-orchestration.md)
- Strict hook promotion: [harness-evidence-and-enforcement.md](harness-evidence-and-enforcement.md)
