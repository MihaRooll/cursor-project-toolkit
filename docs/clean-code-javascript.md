# Clean Code JavaScript — чеклист для агентов

> **AI-first.** Источник: [SRC-018](../SOURCES.md) — [ryanmcdermott/clean-code-javascript](https://github.com/ryanmcdermott/clean-code-javascript) (адаптация Clean Code Роберта Мартина под JS). Не style guide ESLint — читаемость / reuse / refactor.

## For agents

**Когда читать:** пишешь или ревьюишь JS/TS; diff «работает, но грязно»; пользователь кинул clean-code-javascript.

**Применяй (приоритет для агента):**
1. Имена: pronounceable, единый vocabulary, searchable constants (не magic numbers)
2. Функции: ≤2 аргументов идеально (иначе options-object); одна ответственность; имя = что делает
3. Без flag-параметров; без лишних side effects; удаляй dead / duplicate code
4. Concurrency: `async/await` > Promises > callbacks; не глотай reject / catch
5. Comments: только сложная business-логика; не оставляй закомментированный код

**Не делай:**
- Зеркалить весь README (~2k строк bad/good) в toolkit / Essential bootstrap
- Тащить SOLID/composition как dogma в маленьких скриптах (см. [ponytail](ponytail.md) — YAGNI ladder)
- Переписывать чужой стиль ради вкуса в nit-only review ([roles/reviewer](../roles/reviewer.md))

**Вердикт:** **USE on demand** в JS/TS продуктах как рубрика review/implement. Ссылка достаточна; не vendoring.

---

## Быстрая рубрика (по секциям README)

| Секция | Делай | Не делай |
|--------|-------|----------|
| Variables | Meaningful names; same vocab; named constants; explanatory locals | Mental mapping (`l`, `tmp`); лишний контекст в имени (`Car.carMake`) |
| Functions | One thing; one abstraction level; encapsulate conditionals | Flag args; global mutation; type-check спагетти; over-optimize |
| Objects | Getters/setters где нужна валидация; private via closures/`#` | Светить внутренности без нужды |
| Classes | ES6 class > ES5 prototype soup; composition > inheritance | Глубокие иерархии «на вырост» |
| SOLID | SRP/OCP/LSP/ISP/DIP когда модуль растёт | SOLID ради SOLID в 30-строчном util |
| Testing | Один концепт на тест | Мега-тест на всё сразу |
| Concurrency | async/await | Nested callbacks; ignored rejection |
| Errors | Handle / rethrow with context | Empty `catch` / `.catch(() => {})` |
| Formatting | Consistent caps; caller рядом с callee | Война табов в PR без линтера |
| Comments | Why / business complexity | Journal history; section banners; commented-out code |

---

## Agent checklist (перед «готово» на JS/TS)

- [ ] Имена searchable; magic numbers → `const`
- [ ] Функция делает одно; нет boolean flag «mode»
- [ ] Нет мёртвого / дублированного кода в diff
- [ ] Side effects явные и локальные
- [ ] async ошибки не проглочены
- [ ] Комментарии только где логика неочевидна
- [ ] Если overbuild — сверь с [ponytail](ponytail.md)

---

## Связь с toolkit

| Идея | Куда |
|------|------|
| Minimal / YAGNI | [ponytail.md](ponytail.md) |
| Review без style-nits | [roles/reviewer.md](../roles/reviewer.md) |
| Constraint-first | [prompting/constraint-first.md](../prompting/constraint-first.md) |
| Community dump ≠ этот гайд | [prompts-chat-verdict.md](prompts-chat-verdict.md) — здесь курируемый принципный гайд, не prompt dump |

Не класть в Essential bootstrap по умолчанию — язык/домен продукта может быть не JS.

---

## Источник

- https://github.com/ryanmcdermott/clean-code-javascript
- [SRC-018](../SOURCES.md)
