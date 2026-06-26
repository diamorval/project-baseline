# Changelog

All notable changes to this starter base are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project aims to follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Because this is a template you fork rather than a released library, changes are
tracked under `[Unreleased]` until the base itself is versioned.

## [Unreleased]

### Added

- Claude Code automation setup: commit-time hooks (`ruff` + `ruff-format`,
  Prettier, `gitleaks`, plus baseline hygiene and secret checks) and a pre-push
  gate (backend byte-compile + guarded frontend `tsc -b`) via `.pre-commit-config.yaml`.
- `block-.env-secrets` PreToolUse guard so real secrets can't be written into the
  committed `frontend/.env`.
- Project `.mcp.json` wiring the `context7` (live docs) and `postgres` (read-only
  app-db inspection) MCP servers.
- Per-directory `backend/CLAUDE.md` and `frontend/CLAUDE.md` context guides.
- `CONTRIBUTING.md` and this `CHANGELOG.md`.

### Changed

- Rebranded the project to **Baseline** and simplified README onboarding.
- Added a `make init` target to personalise a fresh fork interactively.

[Unreleased]: https://github.com/LittleBigCode/project-baseline/commits/main
