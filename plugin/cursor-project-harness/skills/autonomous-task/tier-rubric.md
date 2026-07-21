# Tier rubric

Сначала проверь T4 overrides, затем Minimum T3. Только если они не сработали, выбирай минимальный T0–T2. Повышение tier требует одной строки evidence. **Число файлов само по себе никогда не повышает tier.**

| Tier | Признаки | Pipeline |
|------|----------|----------|
| T0 | Локальный обратимый однозначный diff, сильный deterministic oracle | Main: research → edit → verify напрямую |
| T1 | Обычный bug/small feature **или** mechanical bounded multi-file (низкий blast/ambiguity/coupling, обратимость, сильный oracle) | Main direct по умолчанию; implementer/verifier опционально |
| T2 | Material ambiguity **или** coupling **или** blast radius **или** weak oracle — не file count | operational-orchestrator; stages conditional |
| T3 | Security/auth/public API/protocol/concurrency/архитектурная развилка | T2 + Sol pre-write + independent review + verify |
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

## Default-down checks

- Не повышай tier только потому, что доступно много дешёвых токенов.
- Не повышай tier только из-за числа файлов — mechanical multi-file с низким риском и сильным oracle остаётся T1.
- Не вызывай Sol «для уверенности» на T0–T2.
- Если требования materially ambiguous, Main задаёт один focused question; ambiguity не маскируется swarm’ом.
