# Changelog

All notable changes to Trackbed are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Spec amendment (2026-07-18): DoD phase-transition gate and the hooks policy.
Gate amendment (2026-07-30): evidence ledger, and doc-comment checking made
diff-conditional rather than tool-conditional.

### Changed
- **`trackbed-dod` verifies the ledger instead of re-executing** (design D12).
  Gate-relevant tools are often run before the gate — independently, or inside a
  language code review that already executes format/build/test. The `## DoD` note
  table now carries a **`sha` column** (that table *is* the ledger); a check
  already satisfied at `HEAD` passes on that evidence and is cited
  `pass (prior run)`. Freshness is **strict sha equality** — any commit since
  invalidates. A surviving artifact (`.trx`, build log, review report) matching
  `HEAD` also passes, and the gate backfills the ledger entry itself. A
  conversational claim alone is not evidence: the gate asks for the summary line,
  else re-runs, reds, or takes a waiver. Provenance is irrelevant; recoverability
  is what matters. Checks 2, 3, 8, and 9 all consult the ledger first.
- **Check 8 (doc comments) is conditional on the diff, not on tooling** (D3
  amended). It applies whenever the phase touched `.cs`/`.cpp`/`.h`, and is
  satisfied by fresh ledger evidence, the doc skill, or the repo's own checker
  (`scripts/check-xml-docs.ps1 -Changed`). When the diff touches those types and
  **no verifier is available the check is red, not skipped** — undocumented public
  surface is a real gap and a missing tool does not make it disappear. Check 9
  keeps `skipped (unavailable)` because it has no offline fallback. New
  distinction: `skipped (n/a)` = nothing to verify; red = subject exists but is
  unverifiable.
- **`trackbed-orchestrate` records the ledger** (D13) — Step 4 gains an explicit
  recording duty: append a row (tool, sha, result) as gate-relevant tools run.
  Foreign skills (`/security-review`, the `orfi-kit-*` skills) are never modified
  — they are built-in/global, so the edit surface stays the skills Trackbed owns.
- **Verification contract defined** (`trackbed-spec.md` §4.4, design D14). Checks
  2/3/8/10 referenced an `ONBOARDING` file whose location and schema were never
  specified, making them unrunnable as written. There is now an **optional**
  `verification:` block (`test`, `build`, `lint`, `doc_check`,
  `project_dod_skill`) in the file recorded as the new manifest field
  `onboarding_path` (default: `ONBOARDING.md`, `docs/ONBOARDING.md`, or
  `CONTRIBUTING.md`). Every field and the block itself are optional — Trackbed
  works in a repo with none of it. Resolution order: contract → obvious repo
  convention → **ask once and offer to record the answer**. Never invent a
  command, never guess twice. `trackbed-init` records `onboarding_path`.
- **Consistency fixes across both variants.** `trackbed-orchestrate`'s
  non-negotiables said "Skills-only … no hooks", contradicting the 2026-07-18
  skills-**first** amendment — corrected there and normalized in `trackbed`,
  `trackbed-init`, `trackbed-adr`, `trackbed-plan`, `trackbed-sync`, and
  `trackbed-view`. `trackbed-orchestrate`'s native phase-shape block was missing
  the `gate:` field defined in spec §4.3 — added. `viz/roadmap.html` was stale
  against the bundled `roadmap-template.html` (missing all gate rendering) —
  resynced. Copilot's `trackbed-view` DATA contract omitted `gate` while its
  bundled template rendered it — documented, matching the claude copy.
  Spec §5's component table listed 5 of 8 skills (`trackbed-plan`,
  `trackbed-sync`, `trackbed-view` missing) and principle 5 named only
  `trackbed-adr` as user-invocable — both corrected; the rule now reads as
  guarding *who may advance the roadmap*, not *who may be typed*.
- **Skills-only principle amended to skills-first** (`trackbed-spec.md` §1,
  §3 principle 4): the core stays skills-first (markdown/YAML by convention,
  roadmap as single source of truth, no required scripts or Python
  dependencies), but hooks are now permitted as an **optional freshness layer
  only** (e.g. regenerating `roadmap.html` on planning-file writes). Hooks
  never enforce anything; Trackbed remains fully usable with no hooks
  installed.

### Added
- **Fourth runtime — OpenAI Codex CLI.** New `codex/` surface: an own adapted skill copy
  (`codex/skills/`, executor text adapted to Codex — Codex CLI itself, or a Codex subagent) with
  **no command file** (in Codex a skill is its own entry point, selected via `/skills` or mentioned
  with `$`). Both installers (`install.sh`, `install.ps1`) gained a `4) OpenAI Codex CLI` option —
  install/uninstall to `$CODEX_HOME/skills` (default `~/.codex/skills/`), independent of the
  Claude/OpenCode/Copilot paths. README (intro, executors, install prompt, layout, where-things-land)
  and spec §7 platform notes updated to four runtimes.
- **`trackbed-plan` skill** — persists a phase's plan into the tracked planning
  layer so no phase is ever executed planless. `[phase]` is optional (defaults to
  the `current` phase). **Simple mode** drafts from the roadmap's `scope`/`done`;
  **tool mode** ("… using superpowers") runs the named tool's planning flow and
  adopts its output — the tool name comes from the prompt, never a fixed argument,
  so Trackbed stays tool-neutral. It is the **only** skill that authors plans and
  the only one that prompts about an existing plan (abort / update / overwrite).
  `trackbed-orchestrate` now checks for a plan at handoff and refuses to dispatch
  without one, pointing at this skill — it never authors the plan itself.
- **`trackbed-sync` skill** — the single definition of the reconcile: refreshes the
  state file, roadmap, phase↔ticket mapping, and regenerates the viewer, then
  verifies every reachable phase has a persisted plan and flags any that don't.
  Read-reconcile only — never advances a phase, authors a plan, or writes Jira.
  `trackbed-orchestrate` Step 4 delegates to it instead of duplicating the logic
  inline, and calls it on **any** material change (a commit landing, a gate/test
  result, a status flip, a scope change, a blocker appearing or clearing) rather
  than only at phase hand-off/return.
- **Both skills registered** in `install.sh` and `install.ps1` and documented in
  the README skill table; both are user-invocable and callable between turns.
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
