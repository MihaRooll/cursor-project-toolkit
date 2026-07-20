# Plan: new-project hardening (post 3×5 review)

> **AI-first.** Следующий slice после реализации plan v2 (`new-project.ps1`). Ревью: GO-with-patch. Не править старый plan-файл в `.cursor/plans/` без нужды — этот файл = SSOT патча.

## For agents

**Когда читать:** продолжение после new-project v2; «фикси NP-01»; hardening перед wifi-vpn unattended.

**Цель:** закрыть blockers + top should-fix; `parse-check` + `smoke-bootstrap` зелёные.

**Не делай:** Full/submodule в happy path; GUI; auto-open Cursor; ForceBrief; vendoring packs; force-push main; ship без просьбы.

---

## Контекст (уже в working tree)

| Есть | Путь |
|------|------|
| Greenfield script | `scripts/new-project.ps1` + `.cmd` |
| `-SkipNext` | `scripts/bootstrap-into-project.ps1` |
| Templates | `templates/product-brief.md`, `templates/first-chat.md` |
| Skill | `.cursor/skills/bootstrap-project/SKILL.md` |
| Smoke TEMP | `scripts/smoke-bootstrap.ps1` section `=== Smoke new-project ===` |
| Docs happy path | `README.md`, `project-workflow/new-project-bootstrap.md`, `docs/bootstrap-scaffold.md` |

Также часто **незакоммичены**: ingest SRC-012…022 + new-project files — `git status` первым.

---

## Severity board (делать по порядку)

| ID | Sev | Fix |
|----|-----|-----|
| NP-01 | blocker | Canonicalize Parent/Target (`GetFinalPathNameByHandle`); **create dirs только после** toolkit-self check на physical path; fail-closed (no Resolve-Path fallback); smoke: junction Parent → fail + no child under toolkit |
| NP-02 | blocker | `docs/harness-as-cursor-plugin.md`: greenfield → `new-project`; existing → Essential bootstrap |
| NP-03 | blocker | `.cursor/rules/toolkit-core.mdc` + `AGENTS.md` layers table: упомянуть `new-project.ps1` |
| NP-04 | should | Честный текст `-AllowExisting` (не «merge-safe»): overwrite `product-core` + hook `.ps1`; files: throw text, skill, `new-project-bootstrap.md`, one line in `bootstrap-scaffold.md` |
| NP-05 | should | Smoke top-5: Essential `mustAbsent` brief/first-chat; refuse non-empty; AllowExisting preserves brief; Name in brief; AGENTS H1 title |
| NP-06 | should | AGENTS title patch устойчив к incomplete + snippet append |
| NP-07 | nit | README Marketplace: day-0 = только `cursor-team-kit`; continual-learning = later |
| NP-08 | nit | Sync `docs/skills-russian-descriptions.md` row = live SKILL description |
| NP-09 | nit | Optional: skip User HOME mutation when `-SkipNext` |

---

## NP-01 design (final)

Fail closed if physical Target equals/under physical ToolkitRoot. Win32 final paths **before** any `New-Item`. No `Resolve-Path` fallback for under-toolkit.

**Order:** (1) Get-FinalPath ToolkitRoot (2) validate Name (3) Parent from param/env/`Split-Path` ToolkitRoot (4) GetFullPath (5) `Resolve-NewProjectParentFinal` (6) Target; if exists Get-FinalPath (7) MAX_PATH on stripped (8) under-check (9) occupied/AllowExisting/git (10) New-Item Parent+Target (11) re-finalize Target before git/bootstrap.

**Get-FinalPath:** `CreateFileW` + `GetFinalPathNameByHandleW`; `FILE_FLAG_BACKUP_SEMANTICS`; no `OPEN_REPARSE_POINT`; `VOLUME_NAME_DOS`; buffer grow; fail-closed.

**Strip:** `\\?\X:\` / `\\?\UNC\` only; keep `\\?\Volume{…}`.

**Smoke C1:** separate TEMP junction Parent→ToolkitRoot; `$code = $LASTEXITCODE` immediate; exit ≠ 0; no `ToolkitRoot\<Name>`; `rmdir` junction (never `Remove-Item -Recurse` on junction). Clear Process `TOOLKIT_PROJECTS_ROOT` during smoke.

**DEFER smoke:** Parent→toolkit-subdir; sibling-junction positive.

---

## DoD

- [ ] `parse-check-ps1.ps1` → ALL_OK
- [ ] `smoke-bootstrap.ps1` → SMOKE PASS (Essential + B1–B3 + C1)
- [ ] P0 docs: «новый продукт ≠ только Essential bootstrap» (нужен `new-project` для git/brief/first-chat); Essential = product subset
- [ ] `-AllowExisting` / Merge text: нет «merge-safe» для полного refresh; overwrite `product-core` + hook `.ps1` явно
- [ ] Ship только если пользователь сказал «зашей»

## После hardening — wifi-vpn (пример)

```bat
cd C:\Users\katko\Desktop\Programms\cursor-project-toolkit
.\scripts\new-project.cmd -Name wifi-vpn -Goal "2 клика: новый WiFi + накатить VPN"
```

Open Folder → paste `docs/first-chat.md` → `/add-plugin cursor-team-kit`.
Строка в `docs/harness-consumers.md` после bootstrap.

## Связанное

- Handoff chat: [continue-chat-prompt.md](continue-chat-prompt.md)
- Checklist UX: [new-project-bootstrap.md](new-project-bootstrap.md)
- Model Essential: [docs/bootstrap-scaffold.md](../docs/bootstrap-scaffold.md)
