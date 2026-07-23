# Autonomous agent orchestration

> **AI-first.** Delegation-first control plane: Main (intent/tier/architecture/T4/final) → Composer product writes T0–T3 → Grok explore/orchestrate/review/verify → Sol T3-only principal. Источники: Cursor docs + Anthropic/OpenAI engineering reports (toolkit registry: SRC-023/024).

## For agents

**Когда читать:** выбрать T0–T4; делегировать Composer/Grok/Sol; спор о Plan Mode; нельзя заявлять done без evidence.

**Применяй:**

1. Main классифицирует по `.cursor/skills/autonomous-task/tier-rubric.md`. **Число файлов само по себе не повышает tier.**
2. **Main never product-writes T0–T3** — Composer `implementer` sole writer.
3. T0: Main Work Packet → Composer → targeted deterministic checks; no plan/Grok review/Sol.
4. T1: Main Work Packet → Composer → Grok `verifier`; no plan; mechanical bounded multi-file may stay T1.
5. T2: Main contract → Grok `operational-orchestrator` conditional stages (explore/plan/implement/review/verify).
6. T3: Grok required plan → Sol Principal Packet до product writes → Composer → Grok review + verify.
7. T4: Human Gate Packet.
8. Production writer один (implementer); параллельны только read-only Explore scouts — **default 0**, max 3 (4-й с justification); premium scouts запрещены.
9. Completion = acceptance + deterministic checks + zero blockers.
10. Verifier/reviewer must not create `_v_*.txt` or temp evidence in product root.

**Не делай:** считать auto-routing, model pin, Sol gate или T4 stop платформенной гарантией; spawn reviewer/verifier из implementer (только Main); resume с явным model slug (omit — reuse prior); отправлять premium-модели raw logs; путать official `/add-plugin orchestrate` с on-disk policy harness; повышать tier только из-за file count; Main product writes на T0–T3; L2 spawn других агентов.

---

## Routing

| Tier | Путь | Human |
|------|------|-------|
| T0 | Main Work Packet → Composer implementer → targeted checks | нет |
| T1 | Main Work Packet → Composer → Grok verifier | нет |
| T2 | Main contract → Grok L1 conditional explore/plan/implement/review/verify L2 | нет |
| T3 | T2 + Sol Principal Packet до product writes + review + verify | нет, если Sol approve |
| T4 | Human Gate Packet; без implementer до approval | да |

Main — classifier, **sole spawn owner**, и user-facing completion owner. L2 agents **never delegate**. Composer `implementer` **never** spawns Task/subagents/reviewer/verifier — если нужна делегация, возвращает управление Main.

## Context budgets (best-effort)

| Packet | Max tokens |
|--------|------------|
| Work/Scope Packet | ≤2k |
| L2 Spawn Packet | ≤8k |
| Scout return | ≤4k |
| Final Report | ≤1.5k |

Forbidden in packets: raw logs, full files, chat history, tool JSON dumps.

## Models

| Agent | Model | Permission |
|-------|-------|------------|
| operational-orchestrator | `cursor-grok-4.5-high-fast` | пишет только `.cursor/plans/**` |
| implementer | `composer-2.5-fast` | sole product writer T0–T3 |
| adversarial-reviewer | `cursor-grok-4.5-high-fast` | readonly; T2 conditional, T3 required |
| verifier | `cursor-grok-4.5-high-fast` | shell checks; T1 required; T2+ when scheduled |
| principal-arbiter | `gpt-5.6-sol-medium` | readonly, T3 only |

### Spawn vs resume (model nuance)

| Call | Model parameter | Behavior |
|------|-----------------|----------|
| **Initial** Task/subagent spawn | **Required** — pass requested model slug (e.g. `composer-2.5-fast`) | Intent pin for that agent instance |
| **Resume** same agent | **Omit** model | Reuses prior agent + model; UI may display **Auto** |
| Verification record | When observable | Record **actual** model used — pin is best-effort, not platform guarantee |

Pin = intent, **not** platform-enforced. Cursor may fallback due to plan/admin/Max/unavailability. Grok/Composer — included pool; Sol T3 only. Routing and model pins in rules/skills are **best-effort** in normal chat — do not describe as hard enforcement.

## Plan Mode vs internal plan

- UI Plan Mode: пользователь явно попросил сначала только план → человек нажимает Build/approve.
- T4 change/build/fix: Human Gate Packet в обычном workflow; это не UI Plan Mode.
- Internal plan artifact: T3 **обязателен**; T2 **conditional** → `.cursor/plans/<contract_id>.plan.md`.
- T0/T1 plan artifact не нужен.

## Evidence protocol

Finding валиден только с:

```yaml
path: path/to/file
lines: 10-20
requirement_ref: AC-1|INV-1
evidence: reproducible observation
```

Review ограничен тремя общими implement→review→verify циклами; цикл 3 — blocker-only. Sol reject — максимум две версии Principal Packet.

Done строго:

- каждый acceptance criterion = pass;
- каждый required command exit code = 0;
- open blockers = 0;
- Main relays Verification Record и создаёт короткий Final Report (≤1.5k);
- VR: implementer T0 targeted; verifier T1+ when scheduled; Main T4 action-only.

Полные schemas: [contracts.md](../.cursor/skills/autonomous-task/contracts.md).

## Verification profiles (light vocabulary)

Profiles name **deterministic command scope** — not runtime/model/plugin proof. Normative detail: contracts.md § Verification profiles.

| Profile | Scope | Toolkit command |
|---------|-------|-----------------|
| `targeted` | Task `verify_commands` | Per Work Packet / Contract |
| `Quick` | Static/policy once each | `scripts/verify-harness.ps1 -Profile Quick` |
| `Full` | Quick + one oracle | `scripts/verify-harness.ps1 -Profile Full` |

**Full due** when any trigger: pre-merge, release, shared config (rules/skills/agents/manifests), public contract change, unknown impact, flake, explicit request.

**INV-7 done checkpoint:**

| Phase | Requirement |
|-------|-------------|
| Until required CI active | Same-SHA local Full (exit 0) unless explicit human deferral in Final Report |
| Green `toolkit-verify` on SHA | May satisfy pre-protection checkpoint; **report protection status** |
| Deferred Full | **≠ done** without INV-7 evidence |

See [ci-toolkit-verify.md](ci-toolkit-verify.md) for workflow boundary. Wave 1 retarget preserved: Quick includes orchestration SelfTest; Full = Quick + `-OracleOnly` once.

## T3 boundary & scouts (3B)

Paired +/- examples (trust boundary, public API, persistence, concurrency, architectural fork): [tier-rubric.md](../.cursor/skills/autonomous-task/tier-rubric.md) § T3 paired examples. **Keyword ≠ tier** — Sol pre-write only for material T3.

| Scouts | Rule |
|--------|------|
| Default | 0 |
| Trigger | Distinct unknown affecting plan/implement |
| Max | 3 read-only explore contours; 4th needs explicit written justification |
| Forbidden | Duplicate scouts, premium scouts, parallel product writers |
| Rework | Resume same scout contour; do not respawn same question |

Normative scout stage detail: [operational-orchestrator.md](../.cursor/agents/operational-orchestrator.md) § Explore scouts.

Shadow evidence (toolkit-only): [orchestration-evidence.md](orchestration-evidence.md) — no strict-hook auto-promotion.

Только в clone самого toolkit: `scripts/validate-orchestration.ps1 -SelfTest` входит в `scripts/verify-harness.ps1 -Profile Quick` (каждый static check один раз). Legacy `smoke-bootstrap.ps1` без `-OracleOnly` по-прежнему может дублировать Quick head. `verify-harness.ps1` не копируется в Essential/Full. В bootstrapped products validator и repo fixtures намеренно отсутствуют.

## Premium packet

Sol получает invariants, validation plan и короткие `{path, lines, excerpt}` refs. Не передавай raw terminal logs, полные файлы, tool JSON или историю всех агентов.

## Guarantees and limits

| Есть | Нет в normal chat |
|------|--------------------|
| Rules/skills/agents, model intent, nesting, deterministic scripts | гарантированного auto-trigger |
| Fresh subagent contexts | гарантированного Sol-before-write |
| Human approval policy | hard T4 filesystem/shell block |
| `.cursor/plans/` artifacts | durable workflow state machine |

Hard routing, budgets and mutation gates — следующий этап через hooks/SDK после eval 10–20 задач (см. orchestration-evidence).

## Official orchestrate plugin

Этот harness работает внутри текущего product repo. `/add-plugin orchestrate` — отдельный official cloud/SDK workflow для параллельных cloud agents; не заменяй один другим автоматически.

---

## Sources

- [Cursor Subagents](https://cursor.com/docs/subagents) / [Plan Mode](https://cursor.com/docs/agent/plan-mode) / [models](https://cursor.com/docs/models-and-pricing) — SRC-023
- [Anthropic multi-agent engineering](https://www.anthropic.com/engineering/multi-agent-research-system); [OpenAI harness](https://openai.com/index/harness-engineering/) / [Symphony](https://openai.com/index/open-source-codex-orchestration-symphony/) — SRC-024
