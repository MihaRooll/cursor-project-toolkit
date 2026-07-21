<!-- cursor-project-toolkit-harness -->

## Toolkit harness (papercuts / patterns)

Bootstrapped from **cursor-project-toolkit** (product Essential). Project rules above still win.

- Failed shells may auto-log to `.papercuts.jsonl` via `.cursor/hooks`.
- Manual: `scripts/papercuts.ps1 add "<friction + fix>" -Tag tooling` (Windows: `$env:HOME = $env:USERPROFILE` if needed).
- Review: `/review-papercuts` or `papercuts list --format md`.
- Patterns: `prompting/`, `roles/`, `subagents/` when relevant.
- Change/build/fix: apply `.cursor/skills/autonomous-task` automatically; T0/T1 Main-direct; T2 conditional stages; T3/T4 strict gates; T4/destructive/external writes stop for human approval.
- Optional: `/add-plugin cursor-team-kit`; local `cursor-project-harness` installs via toolkit `scripts/install-harness-plugin.ps1`, not `/add-plugin`.

<!-- /cursor-project-toolkit-harness -->
