# Project state — cursor-project-toolkit

> Toolkit repo phase tracker (capability-stack review1-fix).

## For agents

**When to read:** session-start hook may inject phase summary; orchestration wave work.

**Apply:** this file tracks **toolkit** evolution, not consumer products.

---

## phase

wave4b — living-eval + strict hook templates + review1 polish

## milestones

| Milestone | Status | Notes |
|-----------|--------|-------|
| Wave 1 orchestration | done | autonomous-task, agents |
| Wave 2 living docs + MCP skill | done | maintain-project-docs, configure skill |
| Wave 3 environment/doctor/stage | done | browser-verify, setup skill, V-SESSION |
| Wave 4 strict hooks + living-eval | done | Full-only templates; Essential mustAbsent evidence skill |
| Wave 4b portability + validators | done | smoke-portability, manifest-driven plugin version |
| Review1 fix (session/doctor/MCP/tests) | in_progress | capability-stack-review1-fix |
| Marketplace plugin publish | pending | human gate |

## next_checks

- [ ] `scripts\project-doctor.ps1` exit 0 or advisory 1 only
- [ ] `scripts\test-session-start-context.ps1` → SESSION_CONTEXT_TEST_PASS
- [ ] `scripts\smoke-bootstrap.ps1` Essential + Full merge + product-local validator
- [ ] `python3 .cursor/plans/_v8_check_review1fix.py` → V8_PASS True

## toolchain_notes

Windows PowerShell 5.1 for hooks/doctor; Python 3 for v8 checker; git required.
