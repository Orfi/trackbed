---
name: trackbed-plan
description: Create or update the persisted plan for a Trackbed phase. Writes the phase's plan file in the tracked planning layer so a phase is never executed planless. Default simple mode drafts from the roadmap's scope/done; naming a tool in the prompt ("using superpowers") runs that tool's planning flow and adopts its output. User-invocable.
---
# Trackbed Plan

Persist the plan for one phase so execution never starts planless. Plans are the durable record; any tool's own planning output is volatile — this skill captures it into the tracked planning layer.

`[phase]` is optional — with no phase, plan the **current** phase (the one at `status: current`). `<key>` is auto-resolved from a single `.trackbed/<key>/` directory; ask only if several exist.

## Hard rules

- **Skills-only.** Read and write markdown by convention; no scripts, no hooks.
- **Never fabricate scope.** Simple mode uses the roadmap's `scope`/`done`; tool mode uses the tool's output. If neither has enough to plan honestly, ask.
- **This skill is the ONLY place that authors plans, and the ONLY place that prompts about an existing plan.** Orchestration never writes plans — it only detects absence and tells the user to run this.
- **Format-aware.** gsd mode → the plan lives under GSD's phases layout (e.g. `.planning/phases/<NN>-<slug>/<NN>-PP-PLAN.md`); native mode → the plans location recorded in the manifest.

## Step 1 — Resolve the phase and locate the plan

1. Read `.trackbed/<key>/manifest.yml` for the `anchor`, `format`, and artifact paths.
2. Resolve the target phase: the `[phase]` argument if given, otherwise the phase at `status: current` in the roadmap.
3. Determine the phase's plan path/folder in the recorded format.

## Step 2 — If a plan already exists, ASK

If a plan file already exists for the phase, stop and ask which to do — take no action until the user chooses:

- **Abort** — leave the existing plan untouched.
- **Update** — reconcile/merge into the existing plan (refresh frontmatter, add missing sections; if a tool is named, merge its output into what's there).
- **Overwrite** — regenerate from scratch (back up the existing plan first).
- Or follow a free-text instruction the user gives instead.

## Step 3 — Author the plan

- **Simple mode (default):** draft the plan from the roadmap's `scope` and `done` criteria for the phase.
- **Tool mode ("… using <tool>"):** the tool name comes from the prompt, never a fixed argument, so Trackbed stays tool-neutral. If the tool's planning output for this phase already exists in the tool's own repo planning folder, adopt it; if it does not, run that tool's planning flow to produce it, then adopt. Map the result into the tracked plan format.

Write the plan file in the recorded format. Then refresh the state file and the roadmap note so the planning layer reflects the new plan; the orchestration loop keeps everything else in sync.

## Handoffs

- Invoked directly by the user (`/trackbed-plan [phase] [using <tool>]`).
- Pointed to by **`trackbed-orchestrate`** when a phase reaches handoff with no persisted plan — orchestration notifies the user to run this skill; it never authors the plan itself.
