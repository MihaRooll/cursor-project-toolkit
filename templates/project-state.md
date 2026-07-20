# Project state

> Living snapshot for agents and humans. Update when phase or priorities change.

## For agents

**When to read:** every session start (via hook summary); before planning slices; with `/setup-project-environment`.

**Apply:** align work to `phase` and `next_checks`; run doctor if stale.

---

## phase

bootstrap

## milestones

| Milestone | Status | Notes |
|-----------|--------|-------|
| Harness bootstrapped | done | Essential or Full from toolkit |
| First vertical slice | pending | See docs/product-brief.md |
| CI / verify loop | pending | cursor-team-kit optional |

## next_checks

- [ ] Run `scripts\project-doctor.ps1` on this machine
- [ ] Fill docs/product-brief.md goal if still placeholder
- [ ] `/setup-project-environment` after doctor — no silent installs

## toolchain_notes

(package manager, Node/Python versions, Windows vs WSL2 — fill after setup skill)
