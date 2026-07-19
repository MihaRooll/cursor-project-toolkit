# Subagent brief: parallel-worker

> Параллельный workstream в своём контексте. Официально: parallel execution в [Subagents](https://cursor.com/docs/subagents).

## For agents (parent)

**Когда спавнить:** 2+ независимых куска (разные директории/задачи); исследование + черновик теста параллельно.

**Правила parent:**
1. Разрежь работу на **непересекающиеся** ownership (пути/файлы)
2. В каждый prompt — полный brief (у subagent нет истории)
3. Собери результаты; разреши конфликты сам
4. Один writer на файл — избегай parallel edit одного path

**Не делай:** 5 агентов на один файл; parallel без merge-плана.

---

## Установка

Создай `.cursor/agents/parallel-worker.md`:

| Frontmatter | Значение |
|-------------|----------|
| `name` | `parallel-worker` |
| `description` | Выполняет изолированный кусок задачи и возвращает итог parent. Для параллельных workstreams с чётким ownership путей. |
| `model` | `inherit` |

**Ожидай во входе:** Goal куска, Allowed paths, Forbidden paths, Done when, Verify commands.

**Выход:**

```
## Done
- …
## Files touched
- …
## Verify
- команда → результат
## Blocked
- …
```

---

## Чеклист перед launch

- [ ] Куски независимы
- [ ] Ownership путей не пересекается
- [ ] Merge/интеграция назначена parent
