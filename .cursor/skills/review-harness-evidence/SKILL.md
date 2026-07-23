---
name: review-harness-evidence
description: Собрать evidence для promotion strict hooks и living-eval; считает теги docs-impact|mcp|destructive-near-miss; чеклист human signoff. Когда просят «доказательства harness», «можно ли включить strict hooks», «review evidence».
---

# Обзор evidence harness (review-harness-evidence)

Toolkit-only skill. **Не** копируется в plugin и **не** auto-promote strict hooks.

## Когда использовать

- Перед merge `templates/hooks/hooks.strict.example.json` в продукт
- После накопления living-eval / papercuts / task tags
- «Достаточно ли evidence для enforcement?»

## Шаги

1. Прочитай [harness-evidence-and-enforcement.md](../../docs/harness-evidence-and-enforcement.md) — пороги promotion.
2. Запусти валидаторы (exit 0):
   - `scripts/validate-living-evals.ps1 -SelfTest` → `EVAL_VALIDATE_PASS`
   - `templates/hooks/dry-run-strict-hooks.ps1` → `STRICT_HOOK_DRYRUN_PASS`
3. **Посчитай теги** по evidence (transcripts, task contracts, papercuts, PR notes):
   | Tag | Что считать |
   |-----|-------------|
   | `docs-impact` | Material change docs/AGENTS/README с docs-map follow-up |
   | `mcp` | MCP profile opt-in, configure-project-integrations, mcp-security |
   | `destructive-near-miss` | Blocked/denied destructive shell or MCP; near-prod action |
4. Проверь пороги:
   - [ ] 10–20 tagged tasks (суммарно по трём тегам)
   - [ ] ≥2 consumer product repos (не только toolkit)
   - [ ] False-deny review: легитимные команды не блокировались без documented exception
   - [ ] Living-eval 12/12 domains green
   - [ ] V-11 dry-run pass
5. Выведи **Human signoff checklist** (не решай за человека):

```markdown
## Strict hook promotion checklist
- [ ] Tagged tasks: ___ / 10–20 (docs-impact: __, mcp: __, destructive-near-miss: __)
- [ ] Consumers documented: ___ / 2 (repo names + links)
- [ ] False-deny signoff owner: ___
- [ ] validate-living-evals -SelfTest: PASS/FAIL
- [ ] dry-run-strict-hooks: PASS/FAIL
- [ ] Product owner approves merge hooks.strict.example.json: YES/NO
```

6. **NEVER** auto-merge strict hooks, bump plugin, or edit active `.cursor/hooks.json` from this skill.

## Запреты

- Не включать `beforeShellExecution` / `beforeMCPExecution` без явного YES от человека
- Не добавлять skill в plugin mirror
- Не считать model votes как evidence

## См. также

- `docs/harness-evidence-and-enforcement.md`
- `/review-papercuts` — friction signal, не promotion gate
