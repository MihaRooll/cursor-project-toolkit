# plan-then-build

> Паттерн: сначала план, потом код. См. Plan Mode в [`docs/cursor-agent-best-practices.md`](../docs/cursor-agent-best-practices.md).

## For agents

**Когда:** material ambiguity, coupling, blast radius, weak oracle, или неочевидные trade-offs — **не** автоматически из-за числа файлов. Смотри `.cursor/skills/autonomous-task/tier-rubric.md`.

**Применяй:**
1. Research (поиск в репо) → уточняющие вопросы при дырах
2. План: цели, файлы, шаги, риски, out-of-scope — **T2 conditional; T3 required; T0/T1 no plan**
3. Если пользователь просил только plan — жди approval (UI Plan Mode / явный OK)
4. Если пользователь просил change/build/fix: `autonomous-task` ведёт T0/T1 Main-direct без plan artifact; T2 — internal plan when plan stage runs; T3 — plan required; T4 ждёт человека
5. Если мимо — revert/уточнить план, не латать длинной перепиской

**Не делай:** писать код при materially ambiguous scope; путать workspace `.cursor/plans/` artifact с UI Plan Mode; «план» без путей файлов; считать >2–3 файлов автоматическим триггером plan/T2.

---

## Когда можно без плана

| Ситуация | План? |
|----------|-------|
| T0/T1 однозначный diff, сильный oracle (в т.ч. mechanical multi-file T1) | Нет |
| Баг с ясным repro + местом | Опционально короткий |
| Material ambiguity / weak oracle / high coupling | Да (T2+) |
| Неясные требования | Да + вопросы |

Для автономного change/build/fix план T2 conditional, T3 required. Approval человека нужен для T4/destructive/external writes или явного запроса «сначала план».

---

## Шаблон плана (минимум)

- **Goal** — 1 предложение
- **Files** — пути create/edit
- **Steps** — упорядоченный список
- **Verify** — команды/чеклист (см. [verify-loop.md](verify-loop.md))
- **Out of scope** — что не трогаем

Сохраняй в `.cursor/plans/` если нужен resume между сессиями.

---

## Чеклист

- [ ] Вопросы заданы (или scope ясен)
- [ ] План с путями файлов (T2+ when plan stage runs)
- [ ] Approval получен для UI Plan Mode; T4 использует отдельный Human Gate Packet; иначе internal plan reviewed
- [ ] Реализация = план; отклонения зафиксированы
