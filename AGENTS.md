# AGENTS Notes

## Lint / Format Scope

- `scripts/lint.sh`, `scripts/format.sh`, `scripts/lint.ps1`, and `scripts/format.ps1`
  exclude these external addons by default:
  - `addons/gdUnit4`
  - `addons/GDQuest_GDScript_formatter`
- To include all addons, set:
  - `EXCLUDE_EXTERNAL_ADDONS=0`
