# Harness > weights: RSI / Metasystem (выжимка)

> Формат: **AI-first → human-second**. Источник: [SRC-002](../SOURCES.md) — [Benchmarks Are Dead (for us)](https://poetiq.ai/posts/benchmarks_are_dead/) (Poetiq, 2026-07-15).

## For agents

**Когда читать:** проектирование toolkit, skills, rules, eval-циклов, субагентов; спор «какой модели достаточно» vs «какой harness нужен».

**Применяй в этом репо:**
- Считай LLM **компонентом**, не всей системой. Улучшай связку: prompts + code + tools + search/strategies + docs
- Цель toolkit = **переиспользуемый harness**, который усиливает любую модель (model-agnostic), а не заточка под одного вендора
- После каждой новой задачи: что из процедуры можно сложить обратно в rules/skills/docs (compounding), **без** копирования чужих данных/секретов
- Статические бенчмарки / «победа ради leaderboard» — слабый критерий готовности; для проектов важнее **живые проверки** на реальных задачах пользователя
- Разнообразие задач улучшает систему сильнее, чем тонкая подгонка одного промпта

**Не делай:**
- Не принимай vendor SOTA-таблицы как доказательство без независимой проверки
- Не подменяй продуктовый DoD «мы обогнали бенчмарк X»
- Не тащи в репо чужие proprietary harness/данные «как есть» — только идеи и свои реализации

**Скепсис (обязательно учитывать):** пост Poetiq — self-report компании; цифры и названия моделей не верифицированы нами. Берём **принцип архитектуры**, не маркетинг.

---

## Суть тезиса (факты из источника)

| Тезис | Смысл |
|-------|--------|
| Intelligence ≠ только weights | Сила в архитектуре вокруг модели: code, prompts, tools, strategies |
| Metasystem / RSI loop | Система сама строит harness под задачу (итеративно улучшает себя) |
| Model-agnostic | Модели — сменные инструменты; выигрыш накапливается в harness |
| Static benchmarks degrade | Когда harness автоматом «решает» бенчмарк, он перестаёт диагностировать |
| Living benchmarks | Динамические/комбинированные проверки на jagged frontiers моделей |

### Категории задач, которые они выделяли

- **Reasoning** — синтез информации (пример в тексте: ARC-AGI)
- **Retrieval** — пределы знаний в весах (пример: Humanity's Last Exam)
- **Coding** — reasoning + retrieval + procedural logic (пример: LiveCodeBench Pro)
- Далее: math, scientific coding, long-horizon planning, agentic tool use, long-context

### Что заявляют как результат подхода

- Автогенерация harness → SOTA на ряде бенчмарков без fine-tune весов
- Часто без leading-модели бенчмарка (более слабая/старая модель + лучший harness)
- Transfer между доменами: стратегия из одной задачи помогает в другой

*(Детали скоров — только в оригинале; в toolkit не копируем таблицы как «истину».)*

---

## Перенос в Cursor Project Toolkit

| Идея Poetiq | Наш артефакт |
|-------------|--------------|
| Harness = code + prompts + tools + strategies | `prompting/`, `rules-and-skills/`, `subagents/`, hooks |
| Metasystem учится на разнообразии задач | Пополнять `docs/` и skills после реальных проектов |
| Model-agnostic | Не хардкодить одного провайдера в правилах |
| Living evaluation | Чеклисты DoD, ревью PR, реальные сценарии — вместо «прошли абстрактный бенчмарк» |
| Agent friction signal | [papercuts](papercuts.md) — жалобы в `.papercuts.jsonl` → чиним harness |
| Compounding | Каждый SRC → выжимка в `docs/` + запись в `SOURCES.md` |

### Мини-чеклист агента при новой практике

- [ ] Можно ли оформить как rule/skill/prompt-шаблон?
- [ ] Работает ли это с разными моделями?
- [ ] Есть ли проверяемый DoD на реальной задаче?
- [ ] Источник зафиксирован в `SOURCES.md`?

---

## Источник

- https://poetiq.ai/posts/benchmarks_are_dead/
- Реестр: [SRC-002](../SOURCES.md)
