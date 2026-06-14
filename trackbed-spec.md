# Trackbed — Specification

**Status:** spec · pre-build → implementing
**Captured:** 2026-06-13
**Companion concept:** `Trackbed-idea.html` (the "rails without the train" brief)

---

## 1. What Trackbed is

Trackbed is a thin **roadmap + status + orchestration** layer for working through a body of work — a Jira **epic** or a standalone **project** — implemented entirely as Claude Code / OpenCode **skills and one slash command** — no scripts, no Python, no hooks.

It keeps the one valuable thing from GSD — the **route and manifest** (ordered phases, dependencies, "what's owed", per-phase memory) — and lets a lightweight executor (Superpowers or vanilla Claude Code) drive each phase. "Keep the rails, lose the train."

Trackbed has two stages:

1. **Initialization** (optional, run-once): turns an epic or project into a roadmap (+ tickets, where applicable). Skippable if a roadmap already exists.
2. **Orchestration** (ongoing): owns the roadmap + status + per-phase notes, hands each phase to the executor, records progress, and absorbs runtime changes to the roadmap.

### Anchors

Every roadmap hangs off an **anchor** (recorded in the manifest as `anchor`):

- **`epic`** — keyed by a Jira epic key (e.g. `PANV-60446`). Phases map to Jira stories; ticketing is part of the flow.
- **`project`** — keyed by a slug (e.g. `sonofanton`) for a small app with no epic. Phases are local stories/tasks; **Jira is optional** (phases may stay 100% local, or be linked/created on request). No fake/dummy epic is ever created.

`<key>` (the epic key or project slug) names the working directory `.trackbed/<key>/` in both anchors.

## 2. Scope

- **Epics or projects — not lone stories.** A single Jira story has no roadmap, so Trackbed does not apply. Stories go straight to execution (Superpowers / vanilla). The only Trackbed capability a story may borrow is ADR intake/create (`trackbed-adr`).
- **Planning + orchestration only.** Trackbed never implements a phase itself; it dispatches to an executor and tracks the result. It is deliberately resilient about *how* a phase gets built.

## 3. Hard rules

1. **No mid-roadmap format switching.** The storage format (GSD vs native Trackbed) is chosen once per roadmap and locked for its life.
2. **Firewall — team-facing outputs stay framework-neutral.** Jira tickets, the PRD, and ADR files must contain **no** GSD/Trackbed vocabulary and **no** `.planning/` or `.trackbed/` paths. They use plain domain language only. Internal phase↔ticket mapping never leaks into Jira.
3. **Always ask before writing to Jira.** Never auto-create or auto-link a ticket silently. Under a `project` anchor, Jira may be unused entirely.
4. **Skills-only.** No executable scripts, no Python dependencies, no hooks. The agent reads/writes markdown/YAML by convention. The roadmap file is the single source of truth and must be re-read (never trusted from stale memory) — this is how the "rails the car can't jump" guarantee is upheld without code.
5. **One front door.** Only `trackbed` is user-invoked. `trackbed-init`, `trackbed-orchestrate`, and `trackbed-adr` are internal skills reached through it (and `trackbed-adr` is also reusable by a story flow).

## 4. Storage model

### 4.1 Manifest (always Trackbed-owned, both modes)

Per-roadmap pointer file: **`.trackbed/<key>/manifest.yml`**. Exists in **both** GSD and native mode and **both** anchors. Holds:

```yaml
anchor: epic | project    # which kind of roadmap this is
key: PANV-60446           # Jira epic key (epic anchor) or project slug (project anchor)
format: gsd | native      # the locked format switch
shape: populated | greenfield   # whether the epic already had stories at init (project → always greenfield)
adr_mode: read | read-create | skip   # how ADRs are handled (default: read)
prd_path: docs/PRD-PANV-60446.md        # where the PRD lives (read or created; may be absent under project anchor)
adr_path: docs/adr/                      # ADR location (may be external/untracked; absent if adr_mode=skip)
roadmap_path: .planning/ROADMAP.md       # gsd mode → GSD file; native → .trackbed/<key>/roadmap.yml
created: 2026-06-13
```

`trackbed-orchestrate` reads the manifest **first** on every resume to learn the anchor, key, artifact paths, and mode.

### 4.2 Roadmap content location (depends on format)

- **GSD mode:** roadmap / status / notes live in GSD's `.planning/` files. Trackbed reads, updates, modifies, and backfills them.
- **Native mode:** roadmap / status / notes live alongside the manifest in `.trackbed/<key>/`:
  - `roadmap.yml` — ordered phases (see §4.3)
  - `state.yml` — current pointer, turn, what's owed
  - `notes/` — per-phase memory (or inlined per phase in `roadmap.yml`)

### 4.3 Native roadmap phase shape

Each phase carries three layers:

```yaml
anchor: epic                    # or: project
key: PANV-60446                 # epic key, or project slug
phases:
  - id: "11.2"                    # decimal insertions allowed at runtime (e.g. 11.2 between 11.1 and 11.3)
    scope: "BFF API-key validation — remove Identity HTTP fallback"
    depends: ["11.1"]
    done: "code + gates"          # explicit done-criteria
    jira: PANV-61955              # link state — see below
    status: done | current | next | blocked | todo
    owes: []                      # gates not yet run, if any
    notes: |                      # per-phase memory (what worked, what didn't, postponed, moved, impl notes)
      ...
```

**Jira link state (three values, drives create/link-ask):**
- `jira: PANV-61955` → linked (exists on board)
- `jira:` absent/null → **not yet ticketed** → trigger "create or link?" ask (epic anchor, or project-with-Jira). Under a `project` anchor with Jira opted out, empty is the normal resting state — no prompt.
- `jira: pending` → decided to create, not yet written

Idempotency comes from: only act on phases whose `jira:` is empty/absent or `pending`; never re-touch a real key. The roadmap **is** the phase↔ticket mapping (no separate `.md` mapping file in native mode).

### 4.4 Lifecycle — `.trackbed/` is scaffolding, not deliverable

`.trackbed/` may be tracked during development but is **noise to a code reviewer**. It must be **removed when the final PR is cut** to merge the work (gitignore, or strip at PR time — same treatment as GSD's `.planning/` via `gsd-pr-branch`).

**Durable / team-facing** (survive the PR): the code, the PRD, the ADRs (in their configured location), and the Jira tickets. **Ephemeral / private** (stripped): `.trackbed/` and `.planning/`.

## 5. Components

| Skill | Tier | Role |
|---|---|---|
| `trackbed` | **user-facing** (the only `/command`) | Front door. Determine anchor (epic/project), route to init or orchestrate. |
| `trackbed-init` | internal | One-time planning: PRD → ADR → roadmap → tickets + set format switch. Skippable. |
| `trackbed-orchestrate` | internal | Living roadmap+status+notes; compute next phase; hand off; record; runtime mutation. |
| `trackbed-adr` | internal + shared | Read existing ADRs, gap-fill new ones. Used by init and by stories. |

### 5.1 `trackbed` (front door)

1. **Determine the anchor.** If given a Jira key → read it via Atlassian MCP, show its type, ask **raw confirmation** ("This is an Epic — full planning or skip to orchestration?"). If it's a story → Trackbed does not apply. If no epic (a small app) → **project anchor**: ask the user for a slug as the key.
2. Check for an existing roadmap / manifest under `.trackbed/<key>/`:
   - **No roadmap** → invoke `trackbed-init` (passing anchor + key), then `trackbed-orchestrate`.
   - **Roadmap exists** → skip init, invoke `trackbed-orchestrate`.
3. Pure dispatcher — does no planning or orchestration itself.

### 5.2 `trackbed-init` (one-time planning pipeline)

**Two epic shapes** (detected from the epic's children, then confirmed with the user — recorded as `shape`):

- **`populated`** — the epic already has stories. The roadmap is built *from* them (import as phases, 1:1 baseline, link-only), ordered with dependencies + done-criteria. Net-new phases/stories only by discussion with the user.
- **`greenfield`** — no stories. Phases are generated from the PRD + ADRs, then ticketed via the full create/link-ask.

In order:

0. **Detect shape — detect, then confirm.** Pull the epic's children via MCP; propose `populated` (children exist) or `greenfield` (none) and confirm. Record `shape`.
1. **PRD — read or create.** If a PRD exists → read & understand. If not → draft from the epic, **user approves**. Record `prd_path`.
2. **ADR — choose mode, then delegate.** Ask the user for `adr_mode` (default `read`): `read` = read existing ADRs to inform ordering, never create; `read-create` = read + propose new ADRs for genuine gaps (user approves); `skip` = no read, no create. Unless `skip`, delegate to `trackbed-adr` (passing the mode). Record `adr_mode` and, unless skipped, `adr_path`.
3. **Roadmap — produce it.** `populated` → import existing stories as ordered phases (pre-fill `jira:` with story keys), discuss any net-new phases. `greenfield` → break the epic into ordered phases from PRD + ADRs. Each phase has id, scope, depends, explicit `done`. **Ask the format switch — GSD or native — record it, locked for the roadmap.** Write the roadmap.
4. **Tickets — create/link, always ask.** For each phase, inspect `jira:`. In `populated` shape most phases are already linked (skip them); the pass mainly covers net-new phases. Empty → ask "create a new ticket or link an existing one?" Never auto-write. New keys written back into the roadmap. All ticket text **framework-neutral** (firewall).

Init ends when: roadmap exists, phases are ticketed, manifest is written (`shape`, `format`, `adr_mode`, paths), format is locked. Does **not** drive execution.

### 5.3 `trackbed-orchestrate` (ongoing orchestration)

1. **Read manifest first**, then roadmap + status in the recorded format.
   - If init was skipped and **no manifest exists**: **detect** the format from files present (`.planning/` vs `.trackbed/`), **confirm with the user** ("detected GSD mode — correct?"), then write the manifest.
2. **Compute "you are here":** next unblocked phase (deps done, not blocked). Show the rail view: done · current · next · blocked-with-reason · todo. Surface what the current/next phase **owes**.
3. **Hand off** the phase: mark in-progress, dispatch to the executor (Superpowers / vanilla). Trackbed does not implement.
4. **Record progress + per-phase notes:** status plus narrative memory — what worked, what didn't, postponed/moved-to-another-phase, implementation notes, forward notes about future phases.
5. **Runtime mutation:** new phases may emerge mid-roadmap (fix gaps/errors). Insert with decimal numbering; run the same create/link-ticket-ask flow; write keys back. The roadmap is a living document.
6. **Authority:** single source of truth for where-we-are / what's-next / what's-done. The executor cannot override it; it always re-reads the roadmap.

### 5.4 `trackbed-adr` (shared ADR intake/create)

Honors the `adr_mode` passed by the caller: **`read`** (default) = steps 1–2 only, create nothing; **`read-create`** = steps 1–3. It is never invoked with `skip` (init simply skips calling it).

1. **Resolve ADR location from config** (this repo's `docs/`, another repo, or a local untracked folder). Ask if unset; never assume.
2. **Scan + read existing ADRs** — the primary job. Understand recorded decisions so planning respects them.
3. **Gap-fill only** (`read-create` only). If decisions implied by the current work are already covered → nothing to create. If there's a genuine gap → propose a new ADR (**global sequential** numbering `ADR-NNNN.md`, conventional format: context / decision / consequences / status), **user approves**.
4. Used inside `trackbed-init` (epic or project) and standalone by a story flow.

## 6. The format switch (summary)

- **Set & record** during `trackbed-init` (step 3).
- **Detect & confirm** during `trackbed-orchestrate` when init was skipped and no manifest exists.
- Either way the mode is written to the manifest and **locked for the roadmap**.
- Downstream skills read/write the matching files: GSD mode → `.planning/`; native mode → `.trackbed/<key>/`.

## 7. Platform notes

- Skills are markdown (`SKILL.md` + YAML frontmatter), compatible with both Claude Code (`~/.claude/skills/`) and OpenCode (reads `~/.claude/skills/` natively; commands need copying to `~/.config/opencode/commands/`).
- In this repo the Trackbed files live under `trackbed/claude/skills/` and `trackbed/claude/commands/`, with this spec at `trackbed/trackbed-spec.md`. Installation into `~/.claude` (and any OpenCode/Copilot mirror) is handled separately (out of scope for the authoring pass).

## 8. Out of scope (parked)

- QML visualization (DAG / Gantt lenses) — see the idea brief, "later, if it earns it."
- SonOfAnton integration — Trackbed ships standalone first; the app can read the same files later.
- Pulling actuals from Jira (sprint dates) for a real Gantt.
