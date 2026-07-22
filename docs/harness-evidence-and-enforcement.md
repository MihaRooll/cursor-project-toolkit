# Harness evidence and enforcement

> **AI-first.** Living-eval framework, strict hook promotion gates, and enforcement hierarchy for Cursor harness.

## For agents

**When to read:** promoting strict hooks; interpreting living-eval cases; IDE vs CLI vs Cloud hook behavior; failClosed semantics; evidence before enforcement changes.

**Apply:**
- Run living-eval validator: `scripts/validate-living-evals.ps1 -SelfTest` → `EVAL_VALIDATE_PASS`
- Strict templates live in `templates/hooks/` — **Full/opt-in only**; never merge `hooks.strict.example.json` into active `.cursor/hooks.json` or plugin
- Promotion requires `/review-harness-evidence` human signoff — **never auto-enable** strict hooks
- Orchestration shadow evidence (`docs/orchestration-evidence.md`, `tests/orchestration/evidence-schema.json`) is **toolkit-only** — also **never auto-promotes** strict hooks
- Essential bootstrap **excludes** `templates/hooks`, `validate-living-evals.ps1`, `tests/living-eval`
- Full bootstrap **includes** those paths for teams opting in after evidence review
- Cloud Agents: `beforeShellExecution` runs **after** writable environment setup; `beforeMCPExecution` **unsupported** on Cloud — do not assume MCP gates there
- `failClosed: true` means hook timeout/error → **deny** (not fail-open); document in product before enabling

**Do not:**
- Ship strict hooks in Essential or plugin 0.5.0 surface
- Invent `server` / `server_name` on beforeMCP stdin (official schema: `tool_name`, `tool_input`, `url` **or** `command`)
- Treat living-eval as model-quality scoring — cases are deterministic policy/fixture asserts only
- Promote enforcement without 10–20 tagged tasks, ≥2 consumer projects, and false-deny signoff

---

## Promotion evidence (strict hooks)

| Gate | Requirement |
|------|-------------|
| Tagged tasks | 10–20 real change/build/fix tasks tagged `docs-impact`, `mcp`, or `destructive-near-miss` |
| Consumers | Evidence from **≥2** bootstrapped product repos (not toolkit-only) |
| False-deny review | Human signoff that deny/ask paths did not block legitimate work (or documented exceptions) |
| Dry-run | `scripts/dry-run-strict-hooks.ps1` exit 0; injection/destructive/malformed cases pass |
| Living-eval | All 12 domains green via `validate-living-evals.ps1 -SelfTest` |
| Active hooks | Merge `hooks.strict.example.json` **only after** explicit human approval per product |

Workflow: `/review-harness-evidence` → checklist → human decision → manual merge (never agent auto-merge).

---

## Living-eval domains (12)

| Domain id | Policy focus |
|-----------|--------------|
| `docs_retrieval` | docs-map paths resolve; retrieval fixtures exist |
| `docs_impact` | Material doc change → map update or `require-human` |
| `mcp_native_preference` | Prefer validated MCP profiles over shell equivalents |
| `mcp_prompt_injection` | Deny instruction-override patterns in tool I/O (`Test-InjectionPhrasesInText` path/filename guard + word-boundary normalize for phrases; JSON key markers; `[SYSTEM]`; instruction-style `SYSTEM:` with `(?<!(?:file ))` on normalized text so `FILE SYSTEM:` / `FILE-SYSTEM:` / `file system:` allow) |
| `memory_poisoning` | Automation memory → human gate before repo truth |
| `destructive_mcp` | Deny token-anchored destructive `tool_name` — `(^|[_-])(delete|drop|destroy|force[-_]?push|rm|rmdir)($|[_-])`; nested destructive verbs under action/command/operation/method/verb keys in `tool_input` |
| `production_action` | Deny production host/mutation without Human Gate |
| `stage_context` | Bounded session-start stage injection |
| `recovery_trigger_precision` | Deny **false** stuck claims (new evidence / diff signature); allow recognizing **true** stuck when NL-only + empty delta + same signature |
| `recovery_duplicate_hypothesis` | Deny parallel experiment on duplicate hypothesis fingerprint |
| `recovery_provider_outage` | Premium unavailable → degraded mode + `require-human`; no silent substitution |
| `recovery_no_oracle` | No oracle → deny tournament/experiment auto-DONE |

Manifest: `tests/living-eval/manifest.json` · validator: `scripts/validate-living-evals.ps1`

**Recovery R0a promotion** (separate from strict hooks): see [recovery-escalation.md](recovery-escalation.md) — ≥10 stuck cases, ≥2 projects, papercut tags, explicit human approval before R0b auto-integration.

---

## Hook matrix (IDE / CLI / Cloud)

| Event | Local IDE | CLI | Cloud Agents | Essential default | Full opt-in |
|-------|-----------|-----|--------------|-------------------|-------------|
| `sessionStart` | yes | yes | yes | papercuts + doctor context | same |
| `afterShellExecution` | yes | yes | varies | papercuts auto-log | same |
| `stop` | yes | yes | varies | papercuts nudge | same |
| `beforeShellExecution` | yes | yes | yes (post env write) | **no** | template only |
| `beforeMCPExecution` | yes | yes | **no** | **no** | template only |

Strict templates: [templates/hooks/README.md](../templates/hooks/README.md)

**strict-before-mcp (template):** `Test-InjectionPhrasesInText` skips normalized phrase checks for path/filename-shaped strings; JSON key markers `"ignore…previous…instructions"` / `"system_prompt"` still deny. `Test-InjectionOrProd` collapses `_`/`-`/whitespace before instruction-style `SYSTEM:`; denies normalized `\bsystem prompt\b`, `[SYSTEM]`, and `(?<!(?:file ))SYSTEM\s*:` on normalized text (without matching `FILE SYSTEM:` / `FILE-SYSTEM:` / `file system:`); malformed `tool_input` JSON → deny. `Test-DestructiveInToolInput` walks nested JSON and checks destructive verbs only under `action`/`command`/`operation`/`method`/`verb` keys (benign paths like `deleted_items.txt` are allowed).

---

## failClosed truth

| Setting | Hook succeeds | Hook times out / throws / bad stdout |
|---------|---------------|--------------------------------------|
| `failClosed: false` (default) | allow/deny per JSON | **allow** (fail-open) |
| `failClosed: true` | allow/deny per JSON | **deny** (fail-closed) |

Strict example JSON sets `failClosed: true`. Papercuts active hooks do **not** use failClosed gates.

---

## Enforcement hierarchy (IAM / CI / SCM)

Lowest layer wins for **automation**; hooks are IDE-session gates, not a substitute for infra policy.

```
SCM branch protection + required checks
    ↑
CI secrets / environment approvals
    ↑
Cloud/IDE permissions.json + sandbox.json (opt-in)
    ↑
beforeShell / beforeMCP hooks (opt-in, failClosed)
    ↑
Agent rules/skills + Human Gate (T4/destructive)
```

| Layer | Examples | Owner |
|-------|----------|-------|
| SCM | Protected `main`, required reviews, status checks | Team / GitHub |
| CI | Environment gates, OIDC, no prod deploy from PR | Pipeline |
| IAM | Least-privilege tokens, scoped MCP profiles | Platform |
| Native controls | `permissions.json`, `sandbox.json` | Product repo (Full templates) |
| Hooks | Strict shell/MCP deny patterns | Opt-in after evidence |
| Harness routing | T0–T4 tier rubric, Principal/Human Gate | Agent workflow |

---

## Related

- [project-integrations.md](project-integrations.md) — Essential vs Full matrix
- [harness-over-weights-rsi.md](harness-over-weights-rsi.md) — living evaluation mindset
- [security-in-session-cursor-vs-claude.md](security-in-session-cursor-vs-claude.md) — in-session gates
- [cursor-official-index.md](cursor-official-index.md) — official hooks docs (SRC-029)

## Source

- [Cursor Hooks](https://cursor.com/docs/hooks) · [Cloud Agents](https://cursor.com/docs/cloud-agent) — SRC-029 in [SOURCES.md](../SOURCES.md)
