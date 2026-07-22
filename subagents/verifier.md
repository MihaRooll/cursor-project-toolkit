# Subagent brief: verifier

> Независимая проверка работы. Образец из [Cursor Subagents](https://cursor.com/docs/subagents).

## For agents (parent)

**Когда спавнить:** T1 обязателен (Composer → Grok verifier); T2–T3 когда orchestrator назначает verify stage. **T0 — отдельного verifier нет**; implementer запускает targeted checks.

**Передай в prompt:**

- Goal / acceptance criteria
- Список изменённых файлов или `@Branch`/diff summary
- Команды проверки проекта
- Что считать fail

**Не делай:** просить verifier «улучшить архитектуру» — только validate + report. Не проси писать `_v_*.txt` или temp evidence в product root.

---

## Executable

Essential ставит `.cursor/agents/verifier.md`; этот файл объясняет контракт parent → verifier.

| Frontmatter | Значение |
|-------------|----------|
| `name` | `verifier` |
| `description` | `Deterministic Grok verifier when Main or orchestrator schedules verification (T1 required; T2+ when verify needed). T0 uses implementer targeted checks only.` |
| `model` | `cursor-grok-4.5-high-fast` |
| `readonly` | `false` (нужен shell для tests; product source не редактировать) |

**Тело агента (system prompt):**

1. Ты verifier. Не редактируй product source и не запускай Task/subagents.
2. Сверь реализацию с acceptance criteria.
3. Запусти только указанные non-destructive проверки (tests/typecheck/smoke).
4. Отметь пробелы и регрессии.
5. Верни Verification Record из `.cursor/skills/autonomous-task/contracts.md`; не исправляй код.
6. **Не создавай** `_v_*.txt` или temp evidence в product root.
7. `pass` только при exit 0 для всех required commands, AC pass и zero blockers. Parent сам сжимает record для пользователя.

---

## Связь

- Паттерн сессии: [verify-loop](../prompting/verify-loop.md)
- Роль в том же чате (без изоляции): [roles/reviewer.md](../roles/reviewer.md)
