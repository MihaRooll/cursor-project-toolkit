# Harness provenance (Wave 4C)

> Local drift report for managed harness files — status/diff only; never apply or update.

## For agents

| When | Do |
|------|-----|
| Check local harness drift vs shadow manifest | `scripts/collect-provenance.ps1 -ProjectRoot <root> -ToolkitRoot <toolkit>` |
| Product project without manifest | Doctor prints `provenance: SKIP no local manifest (advisory)` |
| Toolkit repo self-check | Doctor + collector when `shipping/manifest.v1.json` exists locally |
| Schema / forbidden fields | `schemas/provenance.v1.json` |

**Apply**

- Collector reads `shipping/manifest.v1.json` (shadow SSOT) and compares **installed** paths under `-ProjectRoot` to **managed** sources under `-ToolkitRoot`.
- Output defaults to `%TEMP%/cptk-provenance-<guid>.json` — rejects pre-existing paths and reparse ancestors; console prints `output=invocation-owned` only.
- `-SelfTest` covers positive, drift/stale, partial, dirty, forbidden fields, bracket/unicode paths, deterministic hashes.
- `partial` / `stale` / `dirty` / `legacy` completion states are **never** `success`.

**Do not**

- Apply bootstrap, mutate installs, or write provenance into the product tree by default.
- Emit `installed_at`, `username`, `hostname`, absolute/private paths, private remotes, email, or plugin inventory.
- Treat doctor provenance as global freshness — **local drift only**.

## Report fields

| Field | Meaning |
|-------|---------|
| `artifact_id` | Harness artifact (`cursor-project-harness`) |
| `surface_id` | Manifest surface (`essential` default) |
| `source_revision` | Manifest version + content hash |
| `managed_content_digest` | Aggregate of **every** manifest entry on expected side (`entry_id\|destination\|side\|value`, side=`expected`) |
| `installed_digest` | Aggregate of **every** manifest entry on installed side (`entry_id\|destination\|side\|value`, side=`installed`) |
| `dirty_relevance` | Git dirty flags for manifest destinations |
| `completion_state` | `success` \| `partial` \| `stale` \| `dirty` \| `legacy` \| `error` |
| `paths[]` | Per-entry `strategy`, `result`, `source_hash`, `installed_hash` |

## Path strategies

| Policy | Strategy | Compare |
|--------|----------|---------|
| `managed` | `hash-compare` | Source vs installed SHA-256 |
| `managed-block` (AGENTS.md only) | `managed-block-marker` / `managed-block-native` | Marker/snippet/native toolkit AGENTS — not raw template hash |
| `managed-block` (hooks and other paths) | `managed-block-hash-compare` | Exact source vs installed SHA-256 |
| `structural-merge` | `structural-merge-marker` | Bounded markers (hooks.json papercuts events, AGENTS snippet) |
| `seed-only` | `seed-only-skip` | Skipped |
| `plugin-only` / `toolkit-ci-only` | `*-skip` | Skipped |

## Commands

```powershell
# SelfTest
scripts/collect-provenance.ps1 -SelfTest

# Toolkit local report (temp output)
scripts/collect-provenance.ps1 -ProjectRoot . -ToolkitRoot .

# Tests
tests/provenance/test-collect-provenance.ps1

# Doctor (includes provenance when manifest present)
scripts/project-doctor.ps1 -ProjectRoot .
```

## Doctor integration

When `shipping/manifest.v1.json` exists under the project root, doctor invokes the collector and prints:

- `provenance: local state=<completion> drift=N missing=N`
- Optional `provenance: local dirty paths=N`

Advisory exit `1` when completion is not `success`. No global upstream freshness claims.

## Checklist

- [ ] After manifest/bootstrap edits: `validate-shipping-manifest.ps1` then collector SelfTest
- [ ] Forbidden-field scan passes in SelfTest
- [ ] Doctor provenance line present on toolkit repo
- [ ] `validate-project-docs.ps1` after doc/map updates
