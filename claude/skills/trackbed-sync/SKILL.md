---
name: trackbed-sync
description: Reconcile Trackbed planning artifacts and check persisted plans per phase or per explicitly targeted story. Report missing and ambiguous bindings without authoring plans, advancing work, or writing Jira. User-invocable.
---
# Trackbed Sync

Bring every Trackbed planning artifact back in step with the live roadmap in one pass. This is the single definition of the reconcile; `trackbed-orchestrate` calls it from its loop, and you can call it directly between turns.

`<key>` is auto-resolved from a single `.trackbed/<key>/` directory; ask only if several exist.

## Hard rules

- **Read-reconcile only.** Refresh the planning files to match the roadmap. Never advance a phase, never author a plan, never create or link Jira. Those belong to `trackbed-orchestrate`, `trackbed-plan`, and the Jira ask respectively.
- **The roadmap is the single source of truth.** Re-read it from disk first; if any artifact disagrees, the roadmap wins — the artifact is rewritten to match, never the reverse.
- **Skills-first.** Read/write markdown and YAML by convention; no required scripts.
- **Format-aware.** gsd mode → `.planning/STATE.md` + `.planning/ROADMAP.md` + `.trackbed/<key>/phase-jira.md`; native mode → `.trackbed/<key>/state.yml` + `roadmap.yml`.
- **Opt-in story plans.** A GSD phase's explicit `Plan targets:` roster or a native phase's `plan_targets:` list is authoritative for one-plan-per-story checks. Without it, retain the legacy phase-level check; never reinterpret old multi-plan phases by counting files or Jira keys.

## Step 1 — Read the manifest and roadmap

1. Read `.trackbed/<key>/manifest.yml` (anchor, key, format, artifact paths).
2. Re-read the live roadmap + state file in the recorded format.

## Step 2 — Reconcile the planning layer

Bring each artifact into step with the roadmap (rewrite only what drifted):

1. **State file** — refresh `current` (phase + status), blockers, and session digest (`stopped_at`, `resume_hint`). Keep it lean.
2. **Roadmap** — ensure phase rows/status, `owes`, and insertion history match reality (gsd: `.planning/ROADMAP.md`; native: `roadmap.yml`).
3. **Phase↔ticket mapping** — keep it in sync with the roadmap (gsd: `.trackbed/<key>/phase-jira.md`; native: each phase's `jira:` field and `plan_targets:` list). Mirror an explicit story roster without changing Jira or inventing tickets. If a mapping disagrees, report the conflict and preserve the roadmap as authority.
4. **Viewer** — regenerate `.trackbed/<key>/roadmap.html` by rebuilding only the `DATA` object from the live roadmap (delegate to / mirror `trackbed-view`'s Step 2). The viewer is a projection, never a source.

## Step 3 — Plan-presence check

For each phase that is `current` or `todo`-and-reachable:

1. If it has an explicit story-plan roster, inspect plan frontmatter in that phase's tracked plan location. Match each target by exact `phase` and exactly one `jira` key; `plan` is a stable unique identity, not a wave position. If the roster reserves a plan number/path, verify that binding too. Check every target independently. One plan never satisfies another target.
2. Report each missing target as "Phase `<id>` / `<story-key>` has no plan. Run `/trackbed-plan <id> <story-key>`." Report duplicate Jira bindings, duplicate plan identities, wrong-phase bindings, and plans for removed/replaced targets with their file paths. Do not delete, renumber, rebind, or overwrite any plan. An ambiguous binding blocks only that story's handoff, not unrelated stories.
3. If there is no explicit roster, use the legacy phase-level check and message: "Phase `<id>` has no plan. Run `/trackbed-plan <id>`."

This is a read-only plan audit within the reconcile. Do **not** author plans here; `trackbed-plan` owns all plan writing. A failed or ambiguous sync must not advance a phase or erase a plan.

## Step 4 — Report

Print a one-line summary of what changed (which files were refreshed, any plan gaps flagged), so the reconcile is auditable rather than silent.

## Handoffs

- Invoked directly by the user (`/trackbed-sync`) to reconcile on demand between orchestration turns.
- Invoked by **`trackbed-orchestrate`** on any material change (a commit landing, a gate/test result, a status flip, a scope change, a blocker appearing/clearing) so its loop keeps everything current without duplicating the reconcile logic.
