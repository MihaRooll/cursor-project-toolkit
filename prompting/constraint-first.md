# constraint-first

> Паттерн: сначала рамки, потом решение. Снижает переделки и scope creep.

## For agents

**Когда:** security/API/compat ограничения; «не трогай X»; миграции; пользователь дал жёсткие must/must-not.

**Применяй:**
1. Выпиши constraints **до** дизайна/кода (таблица)
2. Помечай: hard vs soft
3. Любое решение сверяй с hard constraints
4. При конфликте constraints ↔ просьба — спроси, не молча нарушай

**Не делай:** начинать с «красивой архитектуры», игнорируя запреты; расширять scope «заодно».

---

## Шаблон constraints

| ID | Constraint | Hard/Soft | Источник |
|----|------------|-----------|----------|
| C1 | … | hard | user / AGENTS / rule |
| C2 | … | soft | preference |

Примеры hard: no secrets in git; no force-push main; public API stable; readonly exploration.

---

## Порядок работы

1. Constraints table
2. Plan (см. [plan-then-build.md](plan-then-build.md)) совместимый с hard
3. Implement
4. Verify + явная проверка каждого hard constraint

---

## Чеклист

- [ ] Hard constraints записаны
- [ ] План им не противоречит
- [ ] Diff не нарушает C* hard
