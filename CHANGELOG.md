# Changelog

All notable changes to Trackbed are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Spec amendment (2026-07-18): DoD phase-transition gate and the hooks policy.

### Changed
- **Skills-only principle amended to skills-first** (`trackbed-spec.md` §1,
  §3 principle 4): the core stays skills-first (markdown/YAML by convention,
  roadmap as single source of truth, no required scripts or Python
  dependencies), but hooks are now permitted as an **optional freshness layer
  only** (e.g. regenerating `roadmap.html` on planning-file writes). Hooks
  never enforce anything; Trackbed remains fully usable with no hooks
  installed.

### Added
- **Phase-transition gate principle** (`trackbed-spec.md` §3 principle 6):
  the `trackbed-dod` skill gates every phase transition — the outgoing phase
  must carry a green or waived `gate:` stamp before `trackbed-orchestrate`
  may advance; red or missing → refused; human waivers are recorded as
  `gate: waived (date, reason)`. No retro-gating of already-closed phases.
- **`gate:` field** in the native roadmap phase shape (§4.3) and a `gate`
  column in GSD mode's `phase-jira.md` table (§4.2 — GSD's `ROADMAP.md` is
  never modified).
- **`trackbed-dod` row** in the skill table (§5): internal; verifies the
  outgoing phase's DoD checklist with evidence and writes the gate stamp.
- **`trackbed-dod` skill** — ships in the claude variant
  (`claude/skills/trackbed-dod/SKILL.md`) and the copilot variant
  (`copilot/skills/trackbed-dod/SKILL.md`); nine evidence-based checks,
  conditional checks 8–9, pass-through check 10, waiver support, and
  D7 grandfathering. `trackbed-orchestrate` (both variants) enforces the gate
  at transition via the new Step 3b. OpenCode shares the claude variant
  automatically (no separate copy needed).
- **Viewer gate rendering** — the roadmap viewer (`roadmap-template.html`,
  both claude and copilot copies) now renders a per-phase gate badge (green ✓ /
  red ✗ / waived ~ / ungated) in the phase board and shows the full gate stamp
  in the hover tooltip. The `gate:` field is documented in `trackbed-view`'s
  `SKILL.md` DATA contract.
- **Both installers** (`install.sh`, `install.ps1`) now include `trackbed-dod`
  in the skill roster — deployed for Claude Code, OpenCode, and Copilot CLI.

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
