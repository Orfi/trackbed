---
name: trackbed-sync
description: Reconcile the Trackbed planning layer to the live roadmap — refresh the state file, roadmap, phase↔ticket mapping, and regenerate the viewer, then check every phase has a persisted plan and notify if one is missing. Read-reconcile only; never advances a phase, authors a plan, or writes Jira. Callable directly, and invoked by trackbed-orchestrate on any material change. User-invocable.
---
# Trackbed Sync

Bring every Trackbed planning artifact back in step with the live roadmap in one pass. This is the single definition of the reconcile; `trackbed-orchestrate` calls it from its loop, and you can call it directly between turns.

`<key>` is auto-resolved from a single `.trackbed/<key>/` directory; ask only if several exist.

## Hard rules

- **Read-reconcile only.** Refresh the planning files to match the roadmap. Never advance a phase, never author a plan, never create or link Jira. Those belong to `trackbed-orchestrate`, `trackbed-plan`, and the Jira ask respectively.
- **The roadmap is the single source of truth.** Re-read it from disk first; if any artifact disagrees, the roadmap wins — the artifact is rewritten to match, never the reverse.
- **Skills-only.** Read/write markdown and YAML by convention; no scripts.
- **Format-aware.** gsd mode → `.planning/STATE.md` + `.planning/ROADMAP.md` + `.trackbed/<key>/phase-jira.md`; native mode → `.trackbed/<key>/state.yml` + `roadmap.yml`.

## Step 1 — Read the manifest and roadmap

1. Read `.trackbed/<key>/manifest.yml` (anchor, key, format, artifact paths).
2. Re-read the live roadmap + state file in the recorded format.

## Step 2 — Reconcile the planning layer

Bring each artifact into step with the roadmap (rewrite only what drifted):

1. **State file** — refresh `current` (phase + status), blockers, and session digest (`stopped_at`, `resume_hint`). Keep it lean.
2. **Roadmap** — ensure phase rows/status, `owes`, and insertion history match reality (gsd: `.planning/ROADMAP.md`; native: `roadmap.yml`).
3. **Phase↔ticket mapping** — keep it in sync with the roadmap (gsd: `.trackbed/<key>/phase-jira.md`; native: each phase's `jira:` field). Never write a new ticket here — that's the Jira ask in orchestration.
4. **Viewer** — regenerate `.trackbed/<key>/roadmap.html` by rebuilding only the `DATA` object from the live roadmap (delegate to / mirror `trackbed-view`'s Step 2). The viewer is a projection, never a source.

## Step 3 — Plan-presence check

For each phase that is `current` or `todo`-and-reachable, verify a persisted plan exists in the tracked planning layer (the location `trackbed-plan` writes to). If a phase has none, **notify the user** — "Phase `<id>` has no plan. Run `/trackbed-plan <id>`." Do **not** author the plan here; `trackbed-plan` owns all plan writing.

## Step 4 — Report

Print a one-line summary of what changed (which files were refreshed, any plan gaps flagged), so the reconcile is auditable rather than silent.

## Handoffs

- Invoked directly by the user (`/trackbed-sync`) to reconcile on demand between orchestration turns.
- Invoked by **`trackbed-orchestrate`** on any material change (a commit landing, a gate/test result, a status flip, a scope change, a blocker appearing/clearing) so its loop keeps everything current without duplicating the reconcile logic.
