<!-- cursor-project-toolkit-harness -->

## Toolkit harness (papercuts / patterns)

Bootstrapped from **cursor-project-toolkit** (product Essential). Project rules above still win.

- Failed shells may auto-log to `.papercuts.jsonl` via `.cursor/hooks`.
- Manual: `scripts/papercuts.ps1 add "<friction + fix>" -Tag tooling` (Windows: `$env:HOME = $env:USERPROFILE` if needed).
- Review: `/review-papercuts` or `papercuts list --format md`.
- Patterns: `prompting/`, `roles/`, `subagents/` when relevant.
- Optional: `/add-plugin cursor-team-kit`, `/add-plugin cursor-project-harness` (local plugin).

<!-- /cursor-project-toolkit-harness -->
