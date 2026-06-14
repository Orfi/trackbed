# Changelog

All notable changes to Trackbed are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-06-14

First tagged release. Spec and skills authored; multi-runtime install in place.

### Added
- **Five skills** — `trackbed` (front door), `trackbed-init` (one-time
  PRD → ADR → roadmap → tickets pipeline), `trackbed-orchestrate` (living
  roadmap + status + per-phase notes), `trackbed-adr` (ADR intake/create,
  also runnable standalone), and `trackbed-view` (open the roadmap viewer).
- **Roadmap viewer** — a single self-contained HTML page (`viz/roadmap.html`,
  bundled with `trackbed-view`) drawing the roadmap three ways: a phase board
  (story + colour-coded status + Jira key), a rail strip, and a dependency
  graph with the current phase highlighted. `trackbed-orchestrate` regenerates
  it on every status/roadmap change; `trackbed-view` opens it on demand.
- **Two storage modes**, locked once per roadmap: GSD mode (`.planning/`,
  including `STATE.md`) and native mode (`.trackbed/<key>/` with
  `roadmap.yml`, `state.yml`, `manifest.yml`, `notes/`).
- **Dotted-segment phase ordering** (`3 → 3.1 → 3.2 → 3.2.1 → 3.3 → 4`);
  `depends` gates eligibility, "next" is computed each turn (never stored).
- **Two installers** — `install.sh` (macOS/Linux/Git Bash/WSL) and
  `install.ps1` (Windows PowerShell / pwsh): interactive multi-select for
  Claude Code, OpenCode, and GitHub Copilot CLI, with link/uninstall/help.
  Skills get one home per machine to avoid drift across runtimes.
- **Per-runtime surfaces** — `claude/` (skills + command), `opencode/`
  (command only; skills shared with `claude/`), `copilot/` (own skill copy,
  executor text adapted; the skill is its own slash command).
- `user-invocable: false` on `trackbed-init` and `trackbed-orchestrate` to
  enforce the single planning front door; `trackbed`, `trackbed-adr`, and
  `trackbed-view` stay user-invocable.
- README, full specification (`trackbed-spec.md`), and MIT license.

[0.1.0]: https://github.com/Orfi/trackbed/releases/tag/v0.1.0
