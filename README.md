![Trackbed](assets/header.png)

# Trackbed

**Keep the rails, lose the train.**

Trackbed is a thin **roadmap + status + orchestration** layer for working through a body of work — a Jira **epic** or a standalone **project**. It is implemented entirely as Claude Code / OpenCode **skills and one slash command**: no scripts, no Python, no hooks.

It keeps the one genuinely valuable thing from heavier planning frameworks — the **route and manifest** (ordered phases, dependencies, "what's owed", per-phase memory) — and lets a lightweight executor (Superpowers or vanilla Claude Code) drive each phase. Trackbed owns *where you are and what's next*; it never implements a phase itself.

---

## Why

Planning frameworks tend to couple the **route** (the ordered plan you want to keep) to the **engine** (the heavy machinery that drives execution). Trackbed splits them. You keep a durable, re-readable roadmap that the executor cannot jump off of — "the rails the car can't jump" — without paying for an execution engine you didn't want. Any executor can drive; the roadmap stays authoritative.

## How it works

Trackbed has two stages:

1. **Initialization** (optional, run-once) — turns an epic or project into a roadmap (and tickets, where applicable). Skippable if a roadmap already exists.
2. **Orchestration** (ongoing) — owns the roadmap + status + per-phase notes, computes the next unblocked phase, hands it to the executor, records progress, and absorbs runtime changes to the roadmap.

### Anchors

Every roadmap hangs off an **anchor**:

- **`epic`** — keyed by a Jira epic key (e.g. `PANV-60446`). Phases map to Jira stories; ticketing is part of the flow.
- **`project`** — keyed by a slug (e.g. `sonofanton`) for a small app with no epic. Phases are local stories/tasks; **Jira is optional**. No fake/dummy epic is ever created.

The anchor key names the working directory `.trackbed/<key>/`.

## Components

One front door, three internal skills:

| Skill | Tier | Role |
|---|---|---|
| `trackbed` | **user-facing** (the only `/command`) | Front door. Determine the anchor (epic/project), route to init or orchestrate. Pure dispatcher. |
| `trackbed-init` | internal | One-time planning: PRD → ADR → roadmap → tickets, and lock the storage format. Skippable. |
| `trackbed-orchestrate` | internal | Living roadmap + status + notes; compute next phase; hand off; record; absorb runtime mutations. |
| `trackbed-adr` | internal + shared | Read existing ADRs, gap-fill new ones. Used by init and reusable by a story flow. |

## Usage

```
/trackbed <jira-epic-key | project-slug>
```

- `/trackbed PANV-60446` — start or resume Trackbed on a Jira epic.
- `/trackbed sonofanton` — start or resume a standalone project roadmap (no epic).

The front door reads the anchor, checks for an existing roadmap under `.trackbed/<key>/`, then routes to **init** (if nothing exists) or straight to **orchestration** (if a roadmap is already there).

> A single Jira **story** has no roadmap — Trackbed does not apply to it. Stories go straight to execution; they may borrow `trackbed-adr` standalone for decision intake.

## The format switch

The storage format is chosen **once** during init and **locked** for the life of the roadmap:

- **GSD mode** — roadmap / status / notes live in GSD's `.planning/` files (`ROADMAP.md`, `STATE.md`). Trackbed reads and updates them but never alters GSD's roadmap format.
- **Native mode** — roadmap / status / notes live in `.trackbed/<key>/`:
  - `roadmap.yml` — ordered phases (the phase's `jira:` field *is* the phase↔ticket mapping)
  - `state.yml` — cross-phase digest: current position, blockers, session continuity (re-read first every turn)
  - `notes/` — per-phase memory (or inlined per phase in `roadmap.yml`)

The per-roadmap **`manifest.yml`** is always Trackbed-owned and exists in both modes — it records the anchor, key, locked format, ADR mode, and artifact paths. `trackbed-orchestrate` reads it first on every resume.

Phases are walked in **dotted-segment id order** (like version numbers): `3 → 3.1 → 3.2 → 3.2.1 → 3.3 → 4`. `depends` gates eligibility; the id order sets the walk. "Next" is computed each turn — never a stored status.

## Hard rules

1. **No mid-roadmap format switching.** GSD vs native is chosen once and locked.
2. **Firewall.** Team-facing outputs (Jira tickets, PRD, ADRs) stay framework-neutral — plain domain language, no GSD/Trackbed vocabulary, no `.planning/` or `.trackbed/` paths. The phase↔ticket mapping never leaks into Jira.
3. **Always ask before writing to Jira.** Never auto-create or auto-link a ticket. Under a `project` anchor, Jira may be unused entirely.
4. **Skills-only.** No scripts, no Python, no hooks. The roadmap file is the single source of truth and is always re-read, never trusted from stale memory.
5. **One front door.** Only `trackbed` is user-invoked; the rest are reached through it.

## Lifecycle

`.trackbed/` (and `.planning/`) is internal scaffolding — noise to a code reviewer. It **stays git-tracked through development** (never gitignored — an untracked dir is liable to be deleted as noise) and is **removed manually at the very end**, just before the final PR.

**Durable / team-facing** (survive the PR): the code, the PRD, the ADRs, and the Jira tickets.

## Installation

Run the installer and pick your runtime — Claude Code, OpenCode, or both:

```bash
git clone https://github.com/Orfi/trackbed.git
cd trackbed
./install.sh
```

| Flag | Effect |
|---|---|
| *(none)* | Copy the skills + command into place |
| `--link` | Symlink instead of copy — repo edits go live (dev) |
| `--uninstall` | Remove an existing Trackbed install |
| `--help` | Show usage |

Then invoke `/trackbed <jira-epic-key | project-slug>` in either runtime.

### Layout

The skills are markdown (`SKILL.md` + YAML frontmatter). The repo separates each runtime's surface so a future Copilot version can sit alongside:

```
claude/                       # Claude Code surface
├── commands/trackbed.md
└── skills/
    ├── trackbed/SKILL.md
    ├── trackbed-init/SKILL.md
    ├── trackbed-orchestrate/SKILL.md
    └── trackbed-adr/SKILL.md
opencode/                     # OpenCode surface (command only — skills are shared)
└── commands/trackbed.md
install.sh
```

### Where things land

The skills are shared across runtimes; only the command file differs in format. To avoid the two skill homes drifting (OpenCode reads **both** `~/.claude/skills/` and `~/.config/opencode/skills/`), the installer puts skills in exactly **one** home per machine:

| You install for | Skills | Command |
|---|---|---|
| Claude Code only | `~/.claude/skills/` | `~/.claude/commands/trackbed.md` |
| OpenCode only | `~/.config/opencode/skills/` | `~/.config/opencode/commands/trackbed.md` |
| Both | `~/.claude/skills/` *(OpenCode reads it natively)* | both command files |

On an OpenCode-only machine, Claude Code need not be installed — `~/.claude/skills/` is just a path OpenCode also reads; the installer uses the OpenCode-native path instead.

## Status

Spec and skills authored. See [`trackbed-spec.md`](trackbed-spec.md) for the full specification and [`Trackbed-idea.html`](Trackbed-idea.html) for the original "rails without the train" concept brief.

### Out of scope (parked)

- QML visualization (DAG / Gantt lenses).
- SonOfAnton integration — Trackbed ships standalone first; the app can read the same files later.
- Pulling actuals from Jira (sprint dates) for a real Gantt.
