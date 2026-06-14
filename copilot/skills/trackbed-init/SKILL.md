---
name: trackbed-init
description: Internal one-time planning pipeline for Trackbed. Turns a Jira epic — or a standalone project — into an optional PRD, optional ADRs, an ordered roadmap, and (optionally) tickets, then locks the storage format in the manifest. Invoked by trackbed when no roadmap exists. Skippable when a roadmap already exists. Never user-invoked directly; never drives execution.
user-invocable: false
---
# Trackbed Init

One-time planning pipeline that converts a Jira **epic** or a standalone **project** into a roadmap (and, for epics or when wanted, tickets). You are reached **only** through `trackbed`, never invoked directly by the user. `trackbed` passes you the **anchor** (`epic` | `project`) and the **key** (epic key, or project slug). You run the ordered steps below, then stop. You do **not** execute phases — that is `trackbed-orchestrate`'s job.

Skip yourself entirely if a roadmap already exists (`trackbed` will have routed straight to orchestration instead).

## Anchor — epic vs project

- **`epic`** — `<key>` is a Jira epic key. The epic is the source of stories; ticketing is part of the flow.
- **`project`** — `<key>` is a slug (e.g. `acme-app`) for a small app with no epic. There is no epic to read; phases come from the user. **Jira is optional** — phases may stay 100% local, or be linked/created if the user wants.

`<key>` names the working directory `.trackbed/<key>/` in both anchors. Wherever a step below says "the epic", read it as "the epic (epic anchor) or the project (project anchor)".

## Hard rules (never violate)

- **Skills-only.** No scripts, no Python, no hooks. You do everything by reading and writing markdown/YAML by convention.
- **Firewall.** The PRD, the ADRs, and every Jira ticket must be **framework-neutral**: plain domain language only. No "phase", "roadmap", "GSD", "Trackbed", "orchestrate" vocabulary, and no `.planning/` or `.trackbed/` paths in any team-facing output. Internal phase↔ticket mapping never leaks into Jira.
- **Always ask before any Jira write.** Never auto-create or auto-link a ticket. Confirm each one.
- **Format locked once.** The storage format (`gsd` or `native`) is chosen in step 3 and written to the manifest. Never switch it mid-roadmap.
- **Re-read, don't trust memory.** Read files at the moment you need them.

## Prerequisite — the manifest

Before step 1, ensure the per-roadmap manifest exists at **`.trackbed/<key>/manifest.yml`**. This file exists in **both** GSD and native mode and **both** anchors; it is Trackbed's own pointer file and is *not* team-facing. Create it (or read it if present) and fill it in as you complete each step:

```yaml
anchor: epic | project    # from trackbed — which kind of roadmap this is
key: DEMO-100           # epic key (epic anchor) or project slug (project anchor)
format: gsd | native      # set in step 3 — locked for the life of the roadmap
shape: populated | greenfield   # set in step 0 (project anchor is always greenfield)
adr_mode: read | read-create | skip   # set in step 2 — default: read
prd_path: docs/PRD-DEMO-100.md   # set in step 1 (may be absent in project anchor)
adr_path: docs/adr/                 # set in step 2 (may be external/untracked; absent if adr_mode=skip)
roadmap_path: .planning/ROADMAP.md  # set in step 3 — see step 3 for per-mode value
created: 2026-06-13
```

Write `anchor`, `key`, and `created` now; fill the other fields as their steps complete.

## Step 0 — Determine the shape

**Project anchor:** there is no epic to inspect — set `shape: greenfield` and move on. (Phases come from the user in Step 3.)

**Epic anchor — detect, then confirm:** pull the epic's child issues via the Atlassian MCP (`mcp__atlassian__jira_get_epic_issues`, or search issues under the epic). Then **propose a shape and confirm with the user** — never proceed silently:

- **Children exist → propose `populated`.** "This epic already has N stories — build the roadmap from them (link-only), or generate phases from scratch?"
- **No children → propose `greenfield`.** "This epic has no stories — generate phases from scratch?"

Record the confirmed value in the manifest as `shape`. The shape changes how Step 3 (roadmap) and Step 4 (tickets) behave:

- **`populated`** (epic anchor only) — existing stories become the phases (Step 3 imports + orders them; Step 4 is link-only by default, create only when discussed).
- **`greenfield`** — phases are generated from the PRD + ADRs / from the user (Step 3 produces them; Step 4 is the create/link-ask, which is *optional* under a project anchor).

## Step 1 — PRD: read, create, or skip

**Project anchor:** a PRD is optional. Ask the user whether they want one; if not, leave `prd_path` absent and go to Step 2. If yes, draft it from their description (step 3 below).

**Epic anchor:**

1. Look for an existing PRD for this epic (ask the user where it lives if unclear).
2. **If it exists:** read it and understand it. Do not rewrite it.
3. **If it does not exist:** draft a PRD from the epic content (title, description, acceptance criteria pulled via the Atlassian MCP). The PRD is **team-facing** — keep it framework-neutral, plain domain language, no Trackbed jargon and no `.trackbed/`/`.planning/` paths. **Get the user's approval** before saving.
4. Record the final location in the manifest as `prd_path`.

## Step 2 — ADR: choose the mode, then delegate

First, **ask the user how to handle ADRs for this epic/project** and record the answer in the manifest as `adr_mode` (default `read`):

- **`read`** (default) — read existing ADRs to inform ordering; never create.
- **`read-create`** — read existing ADRs and propose new ones for genuine gaps (with user approval).
- **`skip`** — no read, no create. Use when ADRs are irrelevant or handled elsewhere. Skip the rest of this step and leave `adr_path` absent.

Unless `adr_mode` is `skip`, **delegate this step to the `trackbed-adr` skill** — do not scan or author ADRs yourself. Pass it the `adr_mode` so it knows whether creation is permitted:

- `read` → `trackbed-adr` resolves the location, reads existing ADRs, and reports the relevant decisions. It creates nothing.
- `read-create` → same, plus it may propose a new ADR for a genuine gap (user approves).

When it returns (and `adr_mode` ≠ `skip`), record the resolved ADR location in the manifest as `adr_path`. ADRs are **team-facing** — the firewall applies.

## Step 3 — Roadmap: produce it and lock the format

Build the **ordered phases**, branching on the `shape` from Step 0. Either way, each phase needs:
   - `id` — sequential (decimal insertions like `11.2` are allowed later at runtime)
   - `scope` — one-line description of what the phase delivers
   - `depends` — list of phase ids it depends on (`[]` if none)
   - `done` — explicit done-criteria (e.g. `"code + gates"`)

### If `shape: populated` (roadmap from existing stories)

1. Take the epic's child stories (from Step 0). **Import them as phases — 1:1 baseline** (one story → one phase), pre-filling each phase's `jira:` with the existing story key.
2. Derive `scope` from each story's summary, then add the **ordering**: assign `depends` edges and an explicit `done` per phase. This ordering + dependency layer is the roadmap's main value over a flat story list.
3. **Discuss net-new phases/stories with the user.** If the existing stories leave gaps (setup, integration, cross-cutting work), propose **new phases** — and, where a new phase needs its own ticket, a **new story** — but only after discussing with the user. Do not invent phases or tickets silently.
4. Use the PRD + ADRs (Steps 1–2) to inform ordering and to surface gaps, not to override the existing stories.

### If `shape: greenfield` (phases from scratch)

1. Break the work into ordered phases with the fields above, informed by the PRD (Step 1, if any) and the ADRs (Step 2). For an **epic anchor**, source the breakdown from the epic + PRD. For a **project anchor**, source it from the user's description of the app — work *with the user* to define the phases. Leave `jira:` empty (ticketed in Step 4, which is optional under a project anchor).

### Then, for both shapes — lock the format

1. **Ask the format switch now:** "Store this roadmap in GSD mode (`.planning/`) or native Trackbed mode (`.trackbed/<key>/`)?" Record the answer in the manifest `format` field. **This is locked for the life of the roadmap.** (For a project anchor, native mode is usually the natural choice — no Jira board required.)
2. Write the roadmap in the chosen format and set `roadmap_path` in the manifest accordingly:
   - **GSD mode** → write/update GSD's `.planning/ROADMAP.md`; `roadmap_path: .planning/ROADMAP.md`. Do **not** alter GSD's roadmap format. Then create/update `.planning/STATE.md` from GSD's own state template (Current Position → first phase, Session Continuity initialized) — STATE.md is GSD's state layer; let GSD's tooling keep owning its shape.
   - **Native mode** → write `.trackbed/<key>/roadmap.yml`; `roadmap_path: .trackbed/<key>/roadmap.yml`. Use the native phase shape:

```yaml
anchor: epic              # or: project
key: DEMO-100           # epic key, or project slug (e.g. acme-app)
phases:
  - id: "11.1"
    scope: "API-key validation — remove legacy auth fallback"
    depends: []
    done: "code + gates"
    jira:                  # left empty here — ticketed in step 4 (optional under a project anchor)
    status: todo           # persisted status ∈ todo | current | blocked | done ("next" is computed, never stored)
    inserted: false        # true for a runtime decimal insertion (mirrors GSD's "(INSERTED)" marker)
    owes: []
    notes: |
```

   Then create `.trackbed/<key>/state.yml` — the cross-phase digest (mirrors GSD's STATE.md fields), re-read first on every orchestration turn:

```yaml
anchor: epic
key: DEMO-100
current:
  phase: "11.1"            # fast pointer; the authoritative status still lives on the phase
  status: ready-to-plan    # ready-to-plan | planning | in-progress | phase-complete
  last_activity: "2026-06-13 — roadmap created"
blockers: []               # cross-phase concerns, prefixed with originating phase id
session:
  stopped_at: "roadmap created, nothing executed yet"
  resume_hint: "hand off phase 11.1"
```

**Phase ordering (native mode):** order and walk phases by **dotted-segment id comparison**, like version numbers — compare segment by segment as integers, not by numeric value (so `3 → 3.1 → 3.2 → 3.2.1 → 3.3 → 4`, arbitrary depth). `depends` gates *eligibility*; the dotted-id order sets the *walk*. GSD mode inherits GSD's own numeric ordering — don't impose this on it.

The roadmap, `state.yml`, and `phase-jira.md` are internal scaffolding (`.trackbed/` and `.planning/` are deleted manually at the very end, just before the final PR — never gitignored), so phase ids, dependencies, and Trackbed vocabulary are fine here — they just never reach Jira.

## Step 4 — Tickets: create or link, always ask

**Project anchor — Jira is optional.** First ask the user whether this project should use Jira at all. If **no**, skip this entire step: phases stay local with `jira:` empty, and the roadmap is purely local. The user can opt into ticketing later (it runs the same way then). If **yes**, proceed as below. Under an **epic anchor**, this step always runs.

In the **`populated`** shape most phases already carry their story key from Step 3, so this step is largely a no-op (skip every phase that already has a real key). It still runs for any net-new phases you discussed in Step 3. In the **`greenfield`** shape every phase starts empty, so this is the full create/link pass.

For each phase in the roadmap, inspect its **Jira link state** (identical three-state model to `trackbed-orchestrate` and spec §4.3):

| `jira:` value | Meaning | Action |
|---|---|---|
| `PANV-...` (a real key) | Linked — ticket exists on the board | Already done — skip it |
| absent / empty | **Not yet ticketed** | **Ask:** "create a new ticket or link an existing one?" |
| `pending` | Decided to create, write not yet completed | Finish the create, then overwrite with the real key |

For an empty phase:

- If **link** → record the existing key the user gives you.
- If **create** → optionally set `jira: pending` to mark intent, then write the ticket via the Atlassian MCP only after the user confirms the ticket text, then overwrite `pending` with the real key. The ticket body must be **framework-neutral** (firewall): describe the work in domain terms, no phase ids, no roadmap/Trackbed/GSD words, no `.trackbed/`/`.planning/` paths.

Write every resulting key back into the phase↔ticket mapping, **per mode**:
- **Native mode** → the phase's own `jira:` field in `roadmap.yml`. The roadmap *is* the mapping — no separate file.
- **GSD mode** → a separate Trackbed-owned file `.trackbed/<key>/phase-jira.md` (a simple `phase-id → JIRA-KEY` table). **Never modify GSD's `ROADMAP.md` to hold the key.** This file is internal scaffolding (deleted at the end with the rest of `.trackbed/`).

**Idempotency:** only act on phases whose `jira:` is empty/absent **or** `pending`; never re-touch a phase that already carries a real key. Re-running this step is therefore safe.

## Done criteria

Stop when **all** of these hold:
- the roadmap exists in the locked format, and the state file exists alongside it (`.planning/STATE.md` in gsd mode, `.trackbed/<key>/state.yml` in native mode),
- tickets are reconciled per anchor: **epic anchor** → every phase ticketed (linked or created, real keys written back); **project anchor** → either every phase ticketed (if the user opted into Jira) or all phases intentionally local,
- the manifest is written with `anchor`, `key`, `shape`, `format`, `adr_mode`, `roadmap_path`, and (when applicable) `prd_path` and `adr_path` (omitted when not produced / `adr_mode: skip`).

Return control to `trackbed`, which hands off to `trackbed-orchestrate`. You do **not** drive execution.
