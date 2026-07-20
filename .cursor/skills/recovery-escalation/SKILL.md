---
name: recovery-escalation
description: Ручная эскалация recovery при застревании verify — Challenge Packet, scouts, premium review. Только по явному /recovery-escalation; R0a без авто-роя и worktree.
disable-model-invocation: true
---

# Recovery escalation (manual R0a)

Toolkit-only. **Не** копируется в Essential/plugin. **Не** auto-invoke из `autonomous-task`.

## Когда использовать

- Пользователь явно вызвал `/recovery-escalation`
- Задача застряла после исчерпания evidence retries (см. budgets в contracts §14)
- True stuck: та же `normalized_signature` **или** пустой `evidence_delta` — включая NL-only «прогресс» без EvidenceRecord (NL progress ≠ evidence; skill **MAY** run вручную)
- Нужен bounded Challenge Packet для readonly scouts или premium arbiters

## Когда НЕ использовать

- Обычный T0–T4 цикл ещё не исчерпал retries
- **False stuck**: stuck-predicate false — другая `normalized_signature` **и** непустой `evidence_delta` (есть new evidence)
- Environment blocker, external auth, Human Gate без explicit unblock
- Нет явного запроса пользователя на recovery

## Шаги

1. Прочитай [docs/recovery-escalation.md](../../docs/recovery-escalation.md) — taxonomy, stuck predicates, stop table.
2. Прочитай schemas §9–14 в [contracts.md](../autonomous-task/contracts.md).
3. Собери `FailureRecord` + `EvidenceRecord`(s); вычисли `normalized_signature` и `evidence_delta`.
4. Если **не stuck** (другая `normalized_signature` **и** непустой `evidence_delta`) — верни Main: продолжать normal orchestration, recovery не нужен.
5. Если stuck (та же signature **или** пустой `evidence_delta`) — создай **ChallengePacket** (≤12k tokens; без raw logs/secrets/CoT):
   - bounded task contract, invariants, hypotheses, evidence refs, oracle + availability
6. По решению координатора (`recovery-orchestrator`, explicit invoke):
   - `scout` → max 3 readonly Explore contours
   - `premium` → `recovery-arbiter-openai` + `recovery-arbiter-claude` blind review
   - Fable deep **только** после unresolved cross-family conflict и явного deep mode
   - `experiment` → **один** bounded experiment; implementer only on owned paths
   - `reproducer` — scratch diagnostics only; **no product writes**, no Task/delegation
7. Emit `RecoveryDecision` + `RecoverySnapshot`; Main owns user-facing completion.

## Запрещено (R0a)

- Автоматический swarm, `/best-of-n`, competing worktrees
- Product writes вне owned_files
- Silent substitution unavailable premium models
- Изменение acceptance criteria / verify commands
- Создание plans/packets без explicit `/recovery-escalation`

## Verify

```powershell
scripts/validate-recovery.ps1 -SelfTest
```

Ожидается: `RECOVERY_VALIDATE_PASS`
