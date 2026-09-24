---
name: trackbed-plan
description: Create or update a persisted Trackbed plan for a phase or one explicitly targeted story within a phase. Never treat one story plan as coverage for its siblings. User-invocable.
---
# Trackbed Plan

Persist a plan before its work is handed off. A phase may opt into one plan per story; other phases keep their existing phase-plan behavior. Plans are the durable record; any tool's own planning output is volatile — this skill captures it into the tracked planning layer.

Usage: `/trackbed-plan [phase] [story-key] [using <tool>]`. Without a phase, use the **current** phase (`status: current`). `<key>` is the Trackbed roadmap key, auto-resolved from a single `.trackbed/<key>/` directory; `story-key` is the Jira key of one plan target, not the roadmap key.

## Hard rules

- **Skills-first.** Read and write markdown by convention; no required scripts. Hooks, if present, are an optional freshness layer only — never required.
- **Never fabricate scope.** Simple mode uses the roadmap's `scope`/`done`; tool mode uses the tool's output. If neither has enough to plan honestly, ask.
- **This skill is the ONLY place that authors plans, and the ONLY place that prompts about an existing plan.** Orchestration never writes plans — it only detects absence and tells the user to run this.
- **Format-aware.** gsd mode → the plan lives under GSD's phases layout (e.g. `.planning/phases/<NN>-<slug>/<NN>-PP-PLAN.md`); native mode → the plans location recorded in the manifest.
- **Opt-in story mode.** An explicit `Plan targets:` roster in a GSD phase entry, or `plan_targets:` list in a native phase entry, makes each listed story a separate plan target. Without that roster, retain legacy phase-plan behavior, even if the phase has multiple Jira keys or numbered plans. The roadmap roster is authoritative; the phase↔ticket mapping is its mirror.
- **Stable binding.** In story mode, each plan has `phase: <id>`, `plan: <stable number>`, and exactly one `jira: <story-key>` in frontmatter. Never infer a binding from filename order, current wave, or another story's plan; never silently rebind or delete an orphaned plan. Plan numbers do not change when waves change.

## Step 1 — Resolve the phase and locate the plan

1. Read `.trackbed/<key>/manifest.yml` for the `anchor`, `format`, and artifact paths.
2. Resolve the target phase: the `[phase]` argument if given, otherwise the phase at `status: current` in the roadmap.
3. Read the phase's plan-target roster, if any. In story mode, validate the requested `story-key` belongs to it. If omitted, use the sole unplanned target only when exactly one remains; otherwise ask which story to plan. A previously planned story must be named explicitly to update it. Do not choose the first target by default.
4. Locate existing plans by their `phase` and `jira` frontmatter, checking for duplicate, wrong-phase, and orphaned bindings. Stop on ambiguity and name the conflicting files; do not overwrite or repurpose them. For a new GSD story plan, use the target's reserved `<NN>-PP-PLAN.md` identity when the roadmap supplies one; otherwise allocate the next unused number in that phase directory. A reserved filename already occupied by another binding is a conflict, not permission to renumber. In native mode, use the manifest-declared plan location with a stable unique plan identity. Do not create a mandatory phase-wide umbrella plan.
5. Without a roster, determine the legacy phase plan path/folder in the recorded format.

## Step 2 — If a plan already exists, ASK

If the selected target already has a plan, stop and ask which to do — take no action until the user chooses. In story mode these choices affect only the selected story, never a sibling plan:

- **Abort** — leave the existing plan untouched.
- **Update** — reconcile/merge into the existing plan (refresh frontmatter, add missing sections; if a tool is named, merge its output into what's there).
- **Overwrite** — regenerate from scratch (back up the existing plan first).
- Or follow a free-text instruction the user gives instead.

## Step 3 — Author the plan

- **Simple mode (default):** draft from the roadmap's `scope` and `done` criteria. In story mode, also use that story's actual acceptance criteria; if the roadmap/Jira detail is insufficient, ask instead of copying the entire phase scope into one story.
- **Tool mode ("… using <tool>"):** the tool name comes from the prompt, never a fixed argument, so Trackbed stays tool-neutral. If the tool's planning output for this phase already exists in the tool's own repo planning folder, adopt it; if it does not, run that tool's planning flow to produce it, then adopt. Map the result into the tracked plan format.

Write no sibling plan files. In the selected plan, set the exact `phase`, stable `plan`, and single `jira` binding in story mode; do not renumber existing files. Refresh the state file and roadmap note for that target so the planning layer reflects the new plan; the orchestration loop keeps everything else in sync.

## Handoffs

- Invoked directly by the user (`/trackbed-plan [phase] [story-key] [using <tool>]`).
- Pointed to by **`trackbed-orchestrate`** when a phase or selected story reaches handoff with no unique persisted plan — orchestration notifies the user to run this skill; it never authors the plan itself.
