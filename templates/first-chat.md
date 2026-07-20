# Первый чат в этом продукте

Скопируй блок ниже в **новый** Agent-чат Cursor **в этой папке** (не в cursor-project-toolkit).

---

```text
Ты в продуктовом репозитории {{NAME}} (не в cursor-project-toolkit).

Прочитай:
1. @AGENTS.md
2. @docs/product-brief.md
3. @docs/project-state.md (phase / next checks)

Цель продукта (из brief): {{GOAL}}

Сделай:
1. Если цель = "(fill in)" или пустая — сначала спроси у человека одну чёткую Goal, запиши в docs/product-brief.md, потом продолжай.
2. Если docs/project-state.md пустой или шаблонный — предложи `/setup-project-environment` (doctor → propose; Human Gate перед install/auth).
3. Кратко перескажи цель своими словами (2-3 предложения).
4. Предложи 3 варианта First slice (каждый <=1 дня); отметь рекомендуемый.
5. После выбора слайса — передай change/build/fix в `autonomous-task`: он сам выберет tier, агентов, внутренний план и проверки. Для T0–T3 начинай реализацию без отдельного plan approval; T4 останови на human gate.

Не делай:
- не работай как будто это toolkit (нет ship-toolkit / add-source / Full bootstrap)
- не перенастраивай harness (.cursor/hooks, papercuts) без явной просьбы
- не уходи в долгий research без кода после выбора слайса

Если ещё не сделано человеком: напомни одну команду — /add-plugin cursor-team-kit — и сразу продолжай.

Начни с пересказа цели и 3 вариантов First slice; жди выбора, если цель неоднозначна.
```
