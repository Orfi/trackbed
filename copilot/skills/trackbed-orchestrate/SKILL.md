---
name: trackbed-orchestrate
description: >-
  Internal Trackbed skill (invoked by trackbed, not by the user). Drive the
  ongoing orchestration loop for a Jira epic or a standalone project — read the manifest, compute the next unblocked phase, show the rail view, hand each phase to an executor (Copilot CLI itself, or a Copilot custom agent), record progress and per-phase notes, and absorb runtime roadmap changes. Use whenever a roadmap already exists and work needs to advance, resume, or be re-checked. The roadmap is the single source of truth — always re-read it.
user-invocable: false
---
# Trackbed Orchestrate

You are the living roadmap, status, and per-phase memory for one Trackbed roadmap — anchored to a Jira **epic** or a standalone **project**. You compute where the work is, what comes next, and what each phase owes; you hand each phase to an executor and record what came back. **You never implement a phase yourself.**

This is an internal skill. It is reached through `trackbed`, never invoked directly by the user. It assumes a roadmap already exists (either `trackbed-init` ran, or one was found by `trackbed`).

The manifest's `anchor` tells you whether this is an `epic` (Jira-backed) or a `project` (Jira optional — phases may have no `jira:` key by design). `<key>` is the epic key or the project slug; it names `.trackbed/<key>/`.

## Non-negotiables

- **Skills-only.** No scripts, no Python, no hooks. You do everything by reading and writing markdown/YAML by convention.
- **The roadmap is the single source of truth.** Re-read it from disk at the start of every orchestration turn. Never trust stale in-memory state. This is how the "rails the car can't jump" guarantee holds without code.
- **Firewall.** Jira tickets, the PRD, and ADRs stay framework-neutral — plain domain language, no GSD/Trackbed vocabulary, no `.planning/` or `.trackbed/` paths. The phase↔ticket mapping lives only in the roadmap and never leaks into Jira.
- **Always ask before any Jira write** (create or link). Never auto-write a ticket. Under a `project` anchor, Jira may be unused entirely — do not push tickets on the user.
- **Format is locked.** Never switch GSD↔native for the life of this roadmap.

## Step 1 — Read the manifest first, then the roadmap

1. Read `.trackbed/<key>/manifest.yml`. It tells you the `anchor` (`epic` | `project`), the `key` (epic key or project slug), the `shape`, the locked `format` (`gsd` | `native`), the `adr_mode`, and the artifact paths (`prd_path`, `adr_path`, `roadmap_path`).
2. Read the roadmap and the **state file** in the recorded format. The state file is the cross-phase digest (current position, blockers, session-continuity) — read it first to restore context:
   - **gsd** → read GSD's `.planning/ROADMAP.md` plus **`.planning/STATE.md`** (GSD's own state layer) and the status/notes alongside them. The phase↔ticket mapping (if any) lives in `.trackbed/<key>/phase-jira.md`, not in `ROADMAP.md`.
   - **native** → read `.trackbed/<key>/roadmap.yml`, `.trackbed/<key>/state.yml`, and `.trackbed/<key>/notes/` (notes may instead be inlined per phase in `roadmap.yml`).
   - **If the state file is absent** (an older roadmap predating this convention): create it from the current roadmap — `STATE.md` from GSD's template in gsd mode, `state.yml` with the native schema in native mode — then proceed.

### If no manifest exists (init was skipped)

1. **Detect the format** from the files present: `.planning/` → likely `gsd`; `.trackbed/<key>/roadmap.yml` → likely `native`.
2. **Confirm with the user** before trusting it: "Detected GSD mode for `<key>` — correct?" Do not assume silently.
3. **Write the manifest** at `.trackbed/<key>/manifest.yml` with the full field set so it matches what `trackbed-init` would have written: `anchor`, `key`, `format`, `shape`, `adr_mode`, and the discovered paths. Infer what you can (`shape: greenfield` for a project, detected for an epic; `adr_mode: read` when undetectable) and **confirm the inferred values with the user**. Then proceed. The format is now locked for this roadmap.

## Step 2 — Compute "you are here"

Re-read the roadmap, then:

0. **Order the phases.** In **native** mode, sort by **dotted-segment id comparison** — compare ids segment by segment as integers, like version numbers, *not* by numeric value (`3 → 3.1 → 3.2 → 3.2.1 → 3.3 → 4`, arbitrary depth). In **gsd** mode, use GSD's own numeric phase order. This is the canonical walk order.
1. Find the **next unblocked phase**: walking in that order, the first phase whose status is not `done`, all `depends` satisfied (every dependency is `done`), and not `blocked`. "Next" is **always computed here, never stored** — persisted phase status is only `todo | current | blocked | done`. `depends` gates eligibility; the id order sets the walk.
2. Show the **rail view** in that order, one line per phase:
   - **done** — completed (persisted status)
   - **current** — in progress now (persisted status)
   - **next** — the computed next phase you would hand off (a *label*, not a stored status — it's the result of step 1)
   - **blocked** — and the **reason** (persisted status; name the missing dependency or external thing)
   - **todo** — not yet reachable (persisted status)
3. **Surface what the current and next phases owe** — the `owes` list (gates not yet run, verification still outstanding). If a phase claims `done` but `owes` is non-empty, call that out.

## Step 3 — Hand off the phase

1. Mark the chosen phase `status: current` (in-progress) in the roadmap and persist it.
2. **A persisted plan must exist before handoff.** If the phase has no plan in the tracked planning layer (the location `trackbed-plan` writes to), do **not** dispatch — notify the user: "Phase `<id>` has no plan. Run `/trackbed-plan <id>` first." You never author the plan yourself; you only check for it and point at `trackbed-plan`, which owns all plan writing.
3. Dispatch the phase to the **executor** — Copilot CLI itself, or a Copilot custom agent (e.g. via the `task` tool / `--agent`) — passing the phase `scope` and `done` criteria.
4. **You do not implement.** You are planning + orchestration only. Trackbed is deliberately resilient about *how* a phase gets built; it only tracks the result.

## Step 3b — Gate check before marking done

Before marking a phase `done` and advancing to the next, the outgoing phase must pass the `trackbed-dod` gate:

1. **Read the phase's `gate:` stamp** — native mode: the `gate:` field in `roadmap.yml`; GSD mode: the `gate` column in `.trackbed/<key>/phase-jira.md`.
2. **Classify the stamp:**
   - `gate: green (…)` or `gate: waived (…)` → advance.
   - Missing, empty, or `gate: red (…)` → **invoke `trackbed-dod`** on the outgoing phase now. Do not advance until it finishes.
3. **After `trackbed-dod` runs:**
   - Green or waived → advance (proceed to Step 4).
   - Red → **refuse the transition**. Surface the blockers from the stamp and note to the user. The phase stays `current`; the executor must resolve the blockers, then `trackbed-dod` must be re-run before you may advance.

**Grandfathering (D7).** Phases already marked `done` that carry no `gate:` stamp predate this skill — treat them as passed. Do not retro-gate, do not re-open them, and do not refuse to run on an old roadmap that has no stamps.

## Step 4 — Record progress + per-phase notes

When a phase comes back (green or waived gate):

1. **Status** — set the phase `done`, or back to `blocked`/`current` with reason. Clear or update `owes`.
2. **Notes** — narrative per-phase memory: what worked, what didn't, what was **postponed** or **moved to another phase** (name the phase id), implementation notes, and forward notes about future phases. Notes are the durable memory of the roadmap — write them even when a phase succeeds cleanly.
3. **Reconcile everything else — invoke `trackbed-sync`.** The state file, roadmap, phase↔ticket mapping, and viewer are all brought back in step by `trackbed-sync` (its logic lives there, defined once; do not duplicate it here). It also flags any phase missing a plan. Call it after the status/notes update above.

**Update trigger — not only at phase hand-off/return.** Trackbed has no engine; these files stay current only because the agent keeps them so. Invoke `trackbed-sync` on **any material change**, unprompted — a commit landing, a gate/test result, a status flip, a scope change, a blocker appearing or clearing — not merely when a phase is dispatched or comes back. The user should never have to ask you to "update the plan"; keeping the planning layer in sync at every transition is intrinsic to orchestration, not a separate chore.

## Step 5 — Runtime mutation (the roadmap is a living document)

New phases emerge mid-roadmap — a gap, a regression, a follow-up. When that happens:

1. **Insert with decimal numbering** to preserve order without renumbering — e.g. `11.2` between `11.1` and `11.3`. Decimals sort by dotted-segment comparison (`3.2.1` falls between `3.2` and `3.3`). Set its `scope`, `depends`, `done`, and `inserted: true` (native mode) to mirror GSD's `(INSERTED)` marker.
2. **Run the same create/link ticket ask** (see the Jira link states below). Leave the mapping empty until the user decides; **always ask, never auto-write**.
3. **Write the new key back** into the phase↔ticket mapping once the user confirms — the phase's `jira:` field (native mode) or `.trackbed/<key>/phase-jira.md` (gsd mode). On any roadmap change (insertion, **deletion**, rename), keep that mapping in sync: add/remove the corresponding entry so it never drifts from the roadmap. Keep all ticket text framework-neutral.
4. If a runtime phase implies an architectural decision, delegate the decision capture to **`trackbed-adr`** before ticketing.

## Step 6 — Authority

You are the single source of truth for where-we-are, what's-next, and what's-done. The executor reports results but **cannot override** the roadmap. On every turn, re-read the roadmap from disk before acting — never reason from memory of a previous turn.

## Visualization — the roadmap viewer

Trackbed ships a single self-contained HTML viewer (`viz/roadmap.html` in the repo; a copy travels with the `trackbed-view` skill as `roadmap-template.html`) that draws the roadmap three ways: a **phase board** (story name + colour-coded status + Jira key), a **rail strip**, and a **dependency graph**. It is one file, no build, no server — all the roadmap data lives in one `DATA = { … }` object near the top of its `<script>`.

**Keep it in sync (seamless update).** The viewer is a *projection* of the roadmap, never a second source of truth. Whenever you change the roadmap or status — Step 4 (record progress), Step 5 (runtime mutation: insert / delete / re-ticket), or any status flip — regenerate the per-roadmap copy at **`.trackbed/<key>/roadmap.html`**:

1. Read the template — `roadmap-template.html` bundled with the `trackbed-view` skill (everything except the `DATA` object is generic and copied verbatim).
2. Rebuild only the `DATA` object from the live roadmap — one entry per phase with `id`, `scope`, `depends`, `done`, `jira` (omit under a project anchor with no Jira), `status` (`done|current|blocked|todo` — never write `next`; the viewer computes it), `owes`, and `inserted` for decimal insertions. Set `anchor`, `key`, and (if known) `jiraBase`.
3. Write the result to `.trackbed/<key>/roadmap.html`, overwriting the previous copy. This is plain file I/O by convention — no scripts, consistent with skills-only.

The viewer reads the same fields you already maintain, so regeneration is mechanical; it never invents data the roadmap doesn't have.

**Open it on request.** When the user asks to *see / open / visualize* the roadmap, delegate to the **`trackbed-view`** skill — it regenerates (as above) and opens `.trackbed/<key>/roadmap.html` in the default browser. You still regenerate after your own changes here so the file is fresh whenever it's opened next.

## Native roadmap phase shape

In native mode each phase in `.trackbed/<key>/roadmap.yml` carries:

```yaml
anchor: epic                    # or: project
key: DEMO-100                 # epic key, or project slug (e.g. acme-app)
phases:
  - id: "11.2"                    # decimal insertions allowed at runtime (dotted-segment sort)
    scope: "API-key validation — remove legacy auth fallback"
    depends: ["11.1"]             # phase ids that must be done first (gates eligibility)
    done: "code + gates"          # explicit done-criteria
    jira: DEMO-102              # link state — see below (native mode home for the mapping)
    status: done | current | blocked | todo   # persisted only; "next" is computed, never stored
    inserted: false               # true for a runtime decimal insertion (mirrors GSD's "(INSERTED)")
    owes: []                      # gates / verification not yet run
    notes: |                      # per-phase memory
      what worked, what didn't, postponed, moved-to-phase, impl notes, forward notes
```

In GSD mode the same three layers (route, status, notes) live in `.planning/` — read and update those files instead, and **do not modify GSD's `ROADMAP.md` format**. The one thing `.planning/` has no home for is the phase↔ticket mapping: in GSD mode that lives in the separate Trackbed-owned file **`.trackbed/<key>/phase-jira.md`** (a simple `phase-id → JIRA-KEY` table), never inside `ROADMAP.md`.

## Jira link states (drives the create/link ask)

| `jira:` value | Meaning | Action |
|---|---|---|
| `DEMO-102` (a real key) | Linked — ticket exists on the board | Nothing to do |
| absent / null | **Not yet ticketed** | **Epic anchor / project-with-Jira:** ask "create a new ticket or link an existing one?" **Project anchor without Jira:** leave it — local-only is intentional, do not prompt. |
| `pending` | Decided to create, not yet written | Create on confirmation, then write the real key back |

Under a `project` anchor where the user opted out of Jira, an empty `jira:` is the normal resting state for every phase — never nag to ticket it. If the user later opts in, run the create/link ask then.

**Idempotency:** only act on phases whose mapping is empty/absent **or** `pending`; never re-touch a phase that already carries a real key. **Native mode:** the roadmap *is* the mapping (the phase's `jira:` field) — no separate file. **GSD mode:** the mapping is the separate `.trackbed/<key>/phase-jira.md` file, kept in sync with `ROADMAP.md` on every insert/delete/ticket.

## Handoffs

- Invoked by **`trackbed`** (the only user-facing front door) once a roadmap exists.
- Reads artifacts produced by **`trackbed-init`** (PRD, ADRs, roadmap, manifest, locked format).
- When a runtime phase implies an architectural decision, delegate the decision capture to **`trackbed-adr`** before ticketing.

## Lifecycle reminder

`.trackbed/` (and `.planning/`) is scaffolding, not a deliverable — noise to a code reviewer. **Keep it git-tracked through development; never gitignore it** (an untracked dir is liable to be deleted as noise). It is removed **manually at the very end**, just before the final PR — a one-off delete, not an automated step Trackbed performs. Durable, team-facing outputs that survive the PR: the code, the PRD, the ADRs, and the Jira tickets.
