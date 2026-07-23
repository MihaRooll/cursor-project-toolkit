# Tier rubric

Сначала проверь T4 overrides, затем Minimum T3. Только если они не сработали, выбирай минимальный T0–T2. Повышение tier требует одной строки evidence. **Число файлов само по себе никогда не повышает tier.**

| Tier | Признаки | Pipeline |
|------|----------|----------|
| T0 | Локальный обратимый однозначный diff, сильный deterministic oracle | Main Work Packet → Composer implementer → targeted checks |
| T1 | Обычный bug/small feature **или** mechanical bounded multi-file (низкий blast/ambiguity/coupling, обратимость, сильный oracle) | Main Work Packet → Composer implementer → Grok verifier |
| T2 | Material ambiguity **или** coupling **или** blast radius **или** weak oracle — не file count | Main contract → Grok operational-orchestrator; stages conditional → Composer sole writer |
| T3 | Security/auth/public API/protocol/concurrency/архитектурная развилка | T2 chain + Sol pre-write + independent review + verify |
| T4 | Destructive/external/irreversible/high-impact human decision | Human gate |

## Score (tie-breaker)

По 0–2: blast radius, ambiguity, coupling, irreversibility/security, oracle weakness.

- 0–1 → T0
- 2–3 → T1
- 4–10 → T2

Score только различает T0–T2. T3 требует признака из Minimum T3; T4 — только явного T4 override. Высокий score сам по себе не вызывает Sol/human gate.

## Hard overrides

### Minimum T3

- authentication / authorization / security-sensitive product code;
- public API, protocol or persistent data-model contract;
- concurrency/race correctness;
- архитектурное решение с несколькими необратимо дорогими вариантами.

### T4

- secrets or credentials;
- payments/billing mutation;
- production deploy or production database change;
- data loss, destructive reset/delete, irreversible migration;
- `git push`, publish, release, merge or other external write;
- user/account/cloud mutation with material blast radius.

## T3 paired examples (default-down boundary)

**Название темы ≠ tier.** T3 требует **material change** в признаке ниже; иначе держи минимальный T0–T2.

| Область | T3 (+) — Sol pre-write оправдан | Не T3 (−) — держи ниже |
|---------|----------------------------------|-------------------------|
| Trust / security boundary | Меняется trust boundary, permission decision, token/session validation invariant, authz check semantics | Rename переменных, docs, внутренний helper **без** изменения security behavior |
| Public API / protocol | Меняется внешний contract, wire format, compatibility promise, versioning | Реализация **за** неизменным published contract; internal-only call path |
| Persistent data model | Schema/migration/compatibility semantics, stored invariant, backfill rules | Обычный query/mapper/read path без contract change |
| Concurrency / race | Lock/transaction/order/race invariant, shared mutable state correctness | Обычный async/await без shared-state correctness risk |
| Architectural fork | Несколько **необратимо дорогих** вариантов (data plane, tenancy, storage engine) | Локальный refactor с обратимым решением и сильным oracle |

**Настоящий T3 chain (не сокращать):** Grok plan → **один** bounded Sol `principal-arbiter` **до** product writes → Composer implementer (sole writer) → Grok adversarial review → Grok verifier. Второй Sol attempt — только после material packet/evidence change.

## Default-down checks

- Не повышай tier только потому, что доступно много дешёвых токенов.
- Не повышай tier только из-за числа файлов — mechanical multi-file с низким риском и сильным oracle остаётся T1.
- Не вызывай Sol «для уверенности» на T0–T2.
- **Keyword trap:** слова auth/API/migration/concurrency в prompt **не** auto-T3 — см. paired examples; «Fix typo in authentication docs» → T0; «Refactor auth helper variable names» → T1.
- **Stable contract:** implementation behind unchanged published contract → T1/T2, not T3.
- **Scouts default 0** — explore не повышает tier; swarm не заменяет один focused question от Main.
- Main never product-writes T0–T3; Composer implementer — sole product writer.
- Если требования materially ambiguous, Main задаёт один focused question; ambiguity не маскируется swarm’ом.
