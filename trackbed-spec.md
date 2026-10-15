# Trackbed — Specification

**Status:** spec · pre-build → implementing
**Captured:** 2026-06-13
**Companion concept:** `Trackbed-idea.html` (the "rails without the train" brief)

---

## 1. What Trackbed is

Trackbed is a thin **roadmap + status + orchestration** layer for working through a body of work — a Jira **epic** or a standalone **project** — implemented entirely as **skills** (plus one thin slash command on the runtimes that need it) for Claude Code, OpenCode, GitHub Copilot CLI, and OpenAI Codex CLI — no required scripts, no Python dependencies; hooks exist only as an optional freshness layer (see §3, principle 4).

It keeps the one valuable thing from GSD — the **route and manifest** (ordered phases, dependencies, "what's owed", per-phase memory) — and lets a lightweight executor (Superpowers or vanilla Claude Code) drive each phase. "Keep the rails, lose the train."

Trackbed has two stages:

1. **Initialization** (optional, run-once): turns an epic or project into a roadmap (+ tickets, where applicable). Skippable if a roadmap already exists.
2. **Orchestration** (ongoing): owns the roadmap + status + per-phase notes, hands each phase to the executor, records progress, and absorbs runtime changes to the roadmap.

### Anchors

Every roadmap hangs off an **anchor** (recorded in the manifest as `anchor`):

- **`epic`** — keyed by a Jira epic key (e.g. `DEMO-100`). Phases map to Jira stories; ticketing is part of the flow.
- **`project`** — keyed by a slug (e.g. `acme-app`) for a small app with no epic. Phases are local stories/tasks; **Jira is optional** (phases may stay 100% local, or be linked/created on request). No fake/dummy epic is ever created.

`<key>` (the epic key or project slug) names the working directory `.trackbed/<key>/` in both anchors.

## 2. Scope

- **Epics or projects — not lone stories.** A single Jira story has no roadmap, so Trackbed does not apply. Stories go straight to execution (Superpowers / vanilla). The only Trackbed capability a story may borrow is ADR intake/create (`trackbed-adr`) — which also runs standalone on an epic or project when only ADRs are wanted and no roadmap is being built.
- **Planning + orchestration only.** Trackbed never implements a phase itself; it dispatches to an executor and tracks the result. It is deliberately resilient about *how* a phase gets built.

## 3. Hard rules

1. **No mid-roadmap format switching.** The storage format (GSD vs native Trackbed) is chosen once per roadmap and locked for its life.
2. **Firewall — team-facing outputs stay framework-neutral.** Jira tickets, the PRD, and ADR files must contain **no** GSD/Trackbed vocabulary and **no** `.planning/` or `.trackbed/` paths. They use plain domain language only. Internal phase↔ticket mapping never leaks into Jira.
3. **Always ask before writing to Jira.** Never auto-create or auto-link a ticket silently. Under a `project` anchor, Jira may be unused entirely.
4. **Skills-first.** *(Consciously amended 2026-07-18 — supersedes the original skills-only principle.)* The core stays skills-first: the agent reads/writes markdown/YAML by convention; no required executable scripts, no Python dependencies. The roadmap file is the single source of truth and must be re-read (never trusted from stale memory) — this is how the "rails the car can't jump" guarantee is upheld without code. Hooks are permitted as an **optional freshness layer only** (e.g. regenerating `roadmap.html` on planning-file writes); hooks never enforce anything, and Trackbed must remain fully usable with no hooks installed.
5. **One front door for planning.** Only `trackbed` is the planning/orchestration entry point; `trackbed-init`, `trackbed-orchestrate`, and `trackbed-dod` are hidden (`user-invocable: false`) and reached only through it. The exceptions are the **non-orchestrating** skills, which are user-invocable and runnable standalone between turns because none of them advances the roadmap: `trackbed-adr` (ADR intake, also delegated to by `trackbed-init`), `trackbed-plan` (authors a phase or selected story plan), `trackbed-preflight` (checks preparation without advancing), `trackbed-sync` (reconciles the planning layer), `trackbed-view` (opens the viewer), and `trackbed-cleanup` (archives/removes a completed roadmap after confirmation). The rule guards *who may drive the roadmap forward*, not *who may be typed*.
6. **Phase transitions are gated.** The `trackbed-dod` skill gates every phase transition: the outgoing phase must carry a green or waived `gate:` stamp before `trackbed-orchestrate` may advance; a red or missing stamp means the transition is refused. A human may override a red gate — recorded as `gate: waived (date, reason)`, visible and auditable, never silent. The gate applies only to transitions after the skill lands; already-closed phases are never retro-gated. The stamp is one compact line, overwritten each run — current truth only; evidence and history live in the per-phase note.

   **The gate verifies evidence; it does not re-execute.** *(Amended 2026-07-30.)* Each check is satisfied by fresh evidence recorded in the per-phase note's `## DoD` ledger — a `sha` column pinning every result to the commit it was produced at. Evidence is fresh only when its sha equals `HEAD`; any commit since invalidates it. Work done outside the gate (a code review that already ran build/tests, an earlier `/security-review`) counts on equal terms — provenance is irrelevant, recoverability is not. A surviving artifact matching `HEAD` is credited and backfilled into the ledger; an unrecorded claim is not evidence. `trackbed-orchestrate` is the recorder — foreign skills are never modified to report into Trackbed. Checks conditional on the work (doc comments on touched `.cs`/`.cpp`) are conditional on the **diff, not on tool availability**: subject present with no verifier is **red**, never a silent skip.

## 4. Storage model

### 4.1 Manifest (always Trackbed-owned, both modes)

Per-roadmap pointer file: **`.trackbed/<key>/manifest.yml`**. Exists in **both** GSD and native mode and **both** anchors. Holds:

```yaml
anchor: epic | project    # which kind of roadmap this is
key: DEMO-100           # Jira epic key (epic anchor) or project slug (project anchor)
format: gsd | native      # the locked format switch
shape: populated | greenfield   # whether the epic already had stories at init (project → always greenfield)
adr_mode: read | read-create | skip   # how ADRs are handled (default: read)
prd_path: docs/PRD-DEMO-100.md        # where the PRD lives (read or created; may be absent under project anchor)
adr_path: docs/adr/                      # ADR location (may be external/untracked; absent if adr_mode=skip)
onboarding_path: ONBOARDING.md           # optional — where the verification contract lives (§4.4); absent if the repo has none
roadmap_path: .planning/ROADMAP.md       # gsd mode → GSD file; native → .trackbed/<key>/roadmap.yml
created: 2026-06-13
```

`trackbed-orchestrate` reads the manifest **first** on every resume to learn the anchor, key, artifact paths, and mode.

### 4.2 Roadmap content location (depends on format)

- **GSD mode:** roadmap / status / notes live in GSD's `.planning/` files — `ROADMAP.md` plus **`STATE.md`** (GSD's own cross-phase digest, owned by GSD's tooling). Trackbed reads, updates, and backfills them but **never alters GSD's `ROADMAP.md` format**. A phase may opt into story plans with a plain-text `Plan targets:` roster in its existing roadmap entry. The phase↔ticket mapping lives in a separate Trackbed-owned file `.trackbed/<key>/phase-jira.md`, kept in sync with `ROADMAP.md`; it mirrors any explicit plan-target roster and carries the phase DoD `gate` stamp.
- **Native mode:** roadmap / status / notes live alongside the manifest in `.trackbed/<key>/`:
  - `roadmap.yml` — ordered phases (see §4.3); the phase's `jira:` field *is* the phase↔ticket mapping (no separate file)
  - `state.yml` — cross-phase digest mirroring STATE.md's fields: `current` (phase + status), `blockers`, `session` (stopped-at / resume-hint). Re-read first every turn.
  - `notes/` — per-phase memory (or inlined per phase in `roadmap.yml`)

The state file (`STATE.md` in gsd mode, `state.yml` in native mode) is created by `trackbed-init` right after the roadmap, and updated by `trackbed-orchestrate` after every phase.

### 4.3 Native roadmap phase shape

Each phase carries three layers:

```yaml
anchor: epic                    # or: project
key: DEMO-100                 # epic key, or project slug
phases:
  - id: "11.2"                    # decimal insertions allowed at runtime (e.g. 11.2 between 11.1 and 11.3)
    scope: "API-key validation — remove legacy auth fallback"
    depends: ["11.1"]
    done: "code + gates"          # explicit done-criteria
    jira: DEMO-102              # link state — see below
    # plan_targets: [DEMO-102, DEMO-103]  # optional: one persisted plan per listed story
    status: done | current | blocked | todo   # persisted only — "next" is computed each turn, never stored
    gate: "green (2026-07-18, 9/9 checks, tests 47/47)"   # DoD stamp from trackbed-dod — one line, overwritten each run; green | red | waived (date, reason)
    inserted: false               # true for a runtime decimal insertion (mirrors GSD's "(INSERTED)")
    owes: []                      # gates not yet run, if any
    notes: |                      # per-phase memory (what worked, what didn't, postponed, moved, impl notes)
      ...
```

**Phase order.** Phases are stored and walked in **dotted-segment id order** (compare segment by segment as integers, like version numbers, not by numeric value): `3 → 3.1 → 3.2 → 3.2.1 → 3.3 → 4`, arbitrary depth. `depends` gates *eligibility*; id order sets the *walk*. The "next" phase is computed each turn as the first unblocked phase in this order — it is never a stored status. (GSD mode inherits GSD's own numeric ordering.)

**Jira link state (three values, drives create/link-ask):**
- `jira: DEMO-102` → linked (exists on board)
- `jira:` absent/null → **not yet ticketed** → trigger "create or link?" ask (epic anchor, or project-with-Jira). Under a `project` anchor with Jira opted out, empty is the normal resting state — no prompt.
- `jira: pending` → decided to create, not yet written

Idempotency comes from: only act on phases whose mapping is empty/absent or `pending`; never re-touch a real key. **Native mode:** the roadmap *is* the mapping (the phase's `jira:` field) — no separate file. **GSD mode:** since GSD's `ROADMAP.md` is never modified to hold keys, the mapping lives in the separate Trackbed-owned `.trackbed/<key>/phase-jira.md`, kept in sync with `ROADMAP.md` on every insert/delete/ticket.

### 4.3a Opt-in story plans

An explicit GSD `Plan targets:` roster or native `plan_targets:` list makes each listed story a separate plan target. Without one, existing phase-plan behavior is unchanged, including old phases with multiple Jira keys or numbered plans. In GSD mode, plans stay in `.planning/phases/<NN>-<slug>/` as `<NN>-PP-PLAN.md`; a target may reserve its stable `PP` identity in the roadmap. Each story plan has frontmatter `phase: <id>`, unique `plan: <number>`, and exactly one `jira: <story-key>`. Plan numbers are identities, not execution order; reordering preferred waves never renames files.

`trackbed-plan <phase> <story-key>` authors only that target. `trackbed-sync` checks every target independently for missing, duplicate, wrong-phase, reserved-path, or orphaned bindings without authoring plans or changing Jira. `trackbed-orchestrate` hands off only a story with one matching plan; a missing or ambiguous plan blocks that story, not unrelated eligible stories. It records each returned story's evidence in the phase note while the phase stays current. The phase-level DoD remains the aggregate closure gate after all targets have evidence. Jira writes still require the existing explicit ask.

### 4.4 Verification contract (what `trackbed-dod` reads to know how to verify)

Several DoD checks need project-specific commands (test suite, build, lint) and may declare a project DoD skill. Those live in an **optional** block Trackbed reads but never owns, recorded in the manifest as `onboarding_path` (default: the first of `ONBOARDING.md`, `docs/ONBOARDING.md`, or `CONTRIBUTING.md` that exists):

```yaml
verification:
  test: "dotnet test"              # check 2
  build: "dotnet build"            # check 3
  lint: "dotnet format --verify-no-changes"
  doc_check: "pwsh scripts/check-xml-docs.ps1 -Changed"   # check 8 fallback verifier
  project_dod_skill: /my-project-dod                       # check 10 — absent = the check does not exist
```

**Every field is optional, and the block itself is optional** — Trackbed must work in a repo with none of it (this repo has no build or test suite at all). Resolution order per command: the `verification` block → the repo's obvious convention (a lone `*.sln`, `package.json` scripts, a `Makefile` target) → **ask the user once and offer to record the answer**. A command that cannot be resolved makes its check red (unverifiable), not silently skipped — except where the check has no subject at all, which is `skipped (n/a)`. Trackbed never invents a command and never guesses a second time; it records what the user tells it so the next gate is cheaper.

### 4.5 Lifecycle — `.trackbed/` is scaffolding, not deliverable

`.trackbed/` is **noise to a code reviewer**, but it **stays git-tracked through development** — it is *not* gitignored (an untracked dir is liable to be deleted as noise by a panicking agent). After all phases/stories are complete, owed items settled and DoD records accepted under the existing gate/grandfathering rules, orchestration offers **trackbed-cleanup** before the final PR. The skill previews exact paths and requires explicit confirmation, verifies a unique external archive with hashes and recovery metadata, then removes only the selected inventory and stages tracked deletions. It never commits, pushes, merges or rewrites history.

Default scope is `.trackbed/<key>/`, preserving other roadmaps and shared artifacts. An optional manifest `cleanup:` block may declare `backup_root` (absolute external archive parent) and `paths` (exact repository-relative additional removal paths). Arguments may supply those values without configuration. No orfi-kit pointer or other kit is required. Required referenced plans/evidence outside the default directory are archived too; removal of additional paths requires exclusive ownership and explicit selection. Dirty tracked targets, unresolved/shared ownership, unsafe paths or incomplete archives block deletion. Completion merely offers the step; it never authorizes destructive execution. After cleanup, do not regenerate removed state.

**Durable / team-facing** (survive the PR): the code, the PRD, the ADRs (in their configured location), and the Jira tickets. **Ephemeral / private** (eligible after confirmation): the selected `.trackbed/<key>/` and explicitly selected, exclusively owned planning artifacts.

### 4.5 Starting-point and preparation contract

Whole-anchor entry is trackbed <key>; selected phase/story planning entry is trackbed-plan <phase> [story-key]. trackbed-preflight <key> [phase <id> [story <issue-key>]] is also available for preparation alone. Codex uses the corresponding $skill name. Existing anchor/phase selection and story-roster rules remain authoritative.

Trackbed owns this preparation; never invoke a repository preflight skill. Discover actual project instructions, requirements sources and tool/document/environment pointers; impose no repository tree, technology, tracker metadata or credential-store convention. Reuse existing GSD/spec/plan/PRD/ADR artifacts when their target and source revisions match. A framework's presence or GSD storage format is not proof that the checks were performed.

Epic/project preparation establishes objective/non-goals, requirements source, child/external dependencies, cross-cutting constraints and verification approach before roadmap creation. Selected phase/story preparation captures authoritative clauses before source inspection, architecture/contracts, current behavior with citations, direct semantic test bindings with predicted RED, risks and execution prerequisites. Unclear/conflicting requirements block planning; an execution-only blocker does not block safe planning of unrelated work.

Persist a compact artifact reference in existing anchor/phase notes when equivalent preparation exists. Otherwise use .trackbed/<key>/preflight.md for anchor preparation and the existing phase note for exact phase/story sections (fallback .trackbed/<key>/notes/phase-<id>.md). This storage works in either format without changing GSD roadmap shape or adding mandatory manifest fields. Never overwrite sibling story sections.

Init calls preflight after target/shape resolution and reuses PRD/ADR enrichment before roadmap production. Plan reuses/fills preparation before authoring/adopting one plan, preserving requirements revision and AC bindings. Orchestrate validates preparation, current plan and applicable authorization before dispatch; stale/missing work routes to plan rather than implementation. Sync flags known reference drift without executing preflight. DoD consumes the recorded requirements/design references but still needs actual verified outcomes.

Refresh only affected inputs; unrelated commits or elapsed time alone do not force a whole rerun. New requirement/constraint facts update the affected test/plan binding and approval scope. No environment bootstrap, broad credentials discovery, tests/builds, Git/tracker changes or DoD runs in preflight. No global passed flag, extra plan, mandatory packet, duplicate framework ceremony or retro-gating of completed phases. Ready for planning is not implementation approval or DoD PASS.

## 5. Components

| Skill | Tier | Role |
|---|---|---|
| `trackbed` | **user-facing** (the only `/command`) | Front door. Determine anchor (epic/project), route to init or orchestrate. |
| `trackbed-init` | internal | One-time planning: PRD → ADR → roadmap → tickets + set format switch. Skippable. |
| `trackbed-orchestrate` | internal | Living roadmap+status+notes; compute next phase; hand off; record; runtime mutation. |
| `trackbed-preflight` | shared + user-facing | Epic/project and selected phase/story starting checks; reuse equivalent preparation, fill gaps, never author implementation plans or advance. |
| `trackbed-plan` | user-facing | Persist a legacy phase plan or one plan for a selected story in an opted-in phase. The **only** skill that authors plans. |
| `trackbed-sync` | user-facing | Reconcile the planning layer and report missing or ambiguous plans per phase or explicit story target. Read-reconcile only; invoked by orchestrate. |
| `trackbed-adr` | internal + shared + standalone | Read existing ADRs, gap-fill new ones. Used by init, by stories, or standalone on an epic/project that needs only ADRs (no roadmap). |
| `trackbed-view` | user-facing | Regenerate and open the roadmap viewer — one self-contained HTML page (phase board + rail + dependency graph). Read-only projection. |
| `trackbed-cleanup` | user-facing | Archive and remove a completed roadmap's confirmed internal artifacts; preserve other roadmaps, verify backup before deletion, leave uncommitted. |
| `trackbed-dod` | internal | Phase-transition gate: verifies the outgoing phase's DoD checklist with evidence, writes the gate stamp. |

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
0b. **Trackbed-owned preflight.** Prepare the objective, source requirements, dependencies and cross-cutting constraints, reusing equivalent planning evidence. Resolve planning blockers; record child/execution blockers for ordering. Reuse PRD/ADR enrichment below before producing the roadmap.
1. **PRD — read or create.** If a PRD exists → read & understand. If not → draft from the epic, **user approves**. Record `prd_path`.
2. **ADR — choose mode, then delegate.** Ask the user for `adr_mode` (default `read`): `read` = read existing ADRs to inform ordering, never create; `read-create` = read + propose new ADRs for genuine gaps (user approves); `skip` = no read, no create. Unless `skip`, delegate to `trackbed-adr` (passing the mode). Record `adr_mode` and, unless skipped, `adr_path`.
3. **Roadmap — produce it.** `populated` → import existing stories as ordered phases (pre-fill `jira:` with story keys), discuss any net-new phases. `greenfield` → break the epic into ordered phases from PRD + ADRs. Each phase has id, scope, depends, explicit `done`. **Ask the format switch — GSD or native — record it, locked for the roadmap.** Write the roadmap.
4. **Tickets — create/link, always ask.** For each phase, inspect `jira:`. In `populated` shape most phases are already linked (skip them); the pass mainly covers net-new phases. Empty → ask "create a new ticket or link an existing one?" Never auto-write. New keys written back into the roadmap. All ticket text **framework-neutral** (firewall).

Init ends when: roadmap exists, phases are ticketed, manifest is written (`shape`, `format`, `adr_mode`, paths), format is locked. Does **not** drive execution.

### 5.3 `trackbed-orchestrate` (ongoing orchestration)

1. **Read manifest first**, then roadmap + status in the recorded format.
   - If init was skipped and **no manifest exists**: **detect** the format from files present (`.planning/` vs `.trackbed/`), **confirm with the user** ("detected GSD mode — correct?"), then write the manifest.
2. **Compute "you are here":** next unblocked phase (deps done, not blocked). Show the rail view: done · current · next · blocked-with-reason · todo. Surface what the current/next phase **owes**.
3. **Validate preparation/plan/authorization, then hand off** the phase, or one eligible story when the phase opts into story plans, after verifying its unique persisted plan. Trackbed does not implement.
4. **Record progress + per-phase notes:** status plus narrative memory — what worked, what didn't, postponed/moved-to-another-phase, implementation notes, forward notes about future phases.
5. **Runtime mutation:** new phases may emerge mid-roadmap (fix gaps/errors). Insert with decimal numbering; run the same create/link-ticket-ask flow; write keys back. The roadmap is a living document.
6. **Authority:** single source of truth for where-we-are / what's-next / what's-done. The executor cannot override it; it always re-reads the roadmap.

### 5.4 `trackbed-adr` (shared ADR intake/create)

Honors the `adr_mode` passed by the caller: **`read`** (default) = steps 1–2 only, create nothing; **`read-create`** = steps 1–3. It is never invoked with `skip` (init simply skips calling it). When run **standalone** (no caller passes a mode) it defaults to `read` and asks before creating; it needs no manifest or roadmap.

1. **Resolve ADR location from config** (this repo's `docs/`, another repo, or a local untracked folder). Ask if unset; never assume.
2. **Scan + read existing ADRs** — the primary job. Understand recorded decisions so planning respects them.
3. **Gap-fill only** (`read-create` only). If decisions implied by the current work are already covered → nothing to create. If there's a genuine gap → propose a new ADR (**global sequential** numbering `ADR-NNNN.md`, conventional format: context / decision / consequences / status), **user approves**.
4. Used inside `trackbed-init` (epic or project), standalone by a story flow, or standalone on an epic/project that needs only ADRs surfaced or created — with no roadmap involved.

## 6. The format switch (summary)

- **Set & record** during `trackbed-init` (step 3).
- **Detect & confirm** during `trackbed-orchestrate` when init was skipped and no manifest exists.
- Either way the mode is written to the manifest and **locked for the roadmap**.
- Downstream skills read/write the matching files: GSD mode → `.planning/`; native mode → `.trackbed/<key>/`.

## 7. Platform notes

- Skills are markdown (`SKILL.md` + YAML frontmatter), compatible across four runtimes:
  - **Claude Code** — skills at `~/.claude/skills/`, command at `~/.claude/commands/trackbed.md`.
  - **OpenCode** — reads `~/.claude/skills/` natively (or its own `~/.config/opencode/skills/`); command copied to `~/.config/opencode/commands/trackbed.md`.
  - **GitHub Copilot CLI** — skills at `~/.copilot/skills/`; no command file (a skill is its own slash command). Uses its own skill copy because the executor reference differs.
  - **OpenAI Codex CLI** — skills at `$CODEX_HOME/skills/` (default `~/.codex/skills/`); no command file (a skill is its own entry point, selected via `/skills` or mentioned with `$`). Uses its own skill copy because the executor reference differs.
- In this repo each runtime has its own surface: `claude/` (skills + command), `opencode/` (command only — skills shared with `claude/`), and `copilot/` and `codex/` (each its own adapted skill copy). The spec lives at `trackbed/trackbed-spec.md`. Installation into the runtimes is handled by `install.sh` / `install.ps1` (interactive runtime selection), which is install-time plumbing only and does not violate the skills-first rule.
