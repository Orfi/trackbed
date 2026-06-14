---
name: trackbed
description: The user-facing front door for Trackbed — plan and orchestrate a roadmap of phases for either a Jira EPIC or a standalone PROJECT (a small app with no epic). Use whenever the user wants to plan, roadmap, orchestrate, or work through an epic or a project with Trackbed — phrases like "trackbed DEMO-100", "trackbed this app", "plan this epic", "start a roadmap for acme-app", or any request to roadmap/orchestrate a body of work. This is the only Trackbed skill invoked directly; it determines the anchor (epic vs project) and dispatches to trackbed-init and trackbed-orchestrate. A single Jira story has no roadmap — Trackbed does not apply to it.
---
# Trackbed — Front Door

You are the single user-facing entry point for Trackbed. Your job is to determine the **anchor** the roadmap hangs off — a Jira **epic** or a standalone **project** — and dispatch to the right internal skill. You do **no** planning and **no** orchestration yourself — that belongs to `trackbed-init` and `trackbed-orchestrate`. Stay a pure dispatcher.

## When to use

The user wants to plan, roadmap, or work through a body of work with Trackbed. Two entry shapes:
- **Epic** — the user names (or hands you) a Jira epic key.
- **Project** — the user has no epic (a small app like Acme App); they just want a roadmap of phases anchored to the project itself.

## Anchors

Every Trackbed roadmap hangs off an **anchor**, recorded in the manifest as `anchor`:

- **`epic`** — keyed by the Jira epic key (e.g. `DEMO-100`). Phases map to Jira stories; ticketing is part of the flow.
- **`project`** — keyed by a **slug** the user picks (e.g. `acme-app`). Phases are local stories/tasks. **Jira is optional** — phases may stay 100% local, or be linked/created in Jira if the user wants.

The anchor key is what names the working directory: `.trackbed/<key>/` (where `<key>` is the epic key or the project slug).

## Hard rules (inherited from the Trackbed spec — never violate)

- **Skills-only.** No scripts, no Python, no hooks. You do everything by reading and writing Markdown/YAML by convention, and by invoking sibling skills.
- **Always ask before any Jira write.** You do not write to Jira at all in this skill, but downstream skills must ask first — never auto-create or auto-link a ticket.
- **A single story has no roadmap.** Trackbed does not apply to a lone Jira story; it goes straight to execution (Copilot CLI directly, or a Copilot custom agent). A story may borrow `trackbed-adr` standalone.
- **You dispatch, you don't do.** No PRD drafting, no roadmap building, no ticketing, no phase hand-off. Hand those to the internal skills.

## Step 1 — Determine the anchor

Work out which anchor applies from what the user gave you:

- **They gave a Jira key** (e.g. `DEMO-100`) → go to **Step 1a** (epic anchor).
- **They clearly described a standalone project / small app with no epic** → go to **Step 1b** (project anchor).
- **They gave nothing usable, or it's ambiguous** → **ask first**, then route:
  > Is this a **Jira epic** or a **standalone project**? If it's an epic, give me the epic key (e.g. `DEMO-100`); if it's a project, give me a short slug (e.g. `acme-app`).

  Wait for the answer. A key → Step 1a; a slug / "project" → Step 1b.

### Step 1a — Epic anchor

1. If you don't already have the epic key, **ask the user for it** before proceeding.
2. Read the issue via the Atlassian MCP (`mcp__atlassian__jira_get_issue`). Capture its `issuetype`, summary, and status.
3. Show the user the raw facts — key, type, summary — then ask the **raw confirmation** question and wait. Do not proceed on assumption.

   **If it is an Epic**, ask, verbatim in intent:
   > This is an Epic — **full planning** or **skip straight to orchestration**?
   - "Full planning" / unsure → go to Step 2 with `anchor: epic`, key = the epic key.
   - "Skip to orchestration" → treat as the "roadmap exists" branch in Step 2.

   **If it is a Story (or anything other than an Epic)**: tell the user plainly that **Trackbed does not apply** — a single story has no roadmap. It goes straight to execution; it may borrow ADR intake/create via **trackbed-adr**. Stop; do not dispatch to init or orchestrate.

### Step 1b — Project anchor

1. There is no epic. Ask the user for a short **slug** to name this project's roadmap (e.g. `acme-app`). This slug is the anchor key — it names `.trackbed/<slug>/`. Keep it lowercase, hyphenated, stable (it does not change later).
2. Proceed to Step 2 with `anchor: project`, key = the slug.

## Step 2 — Check for an existing roadmap / manifest

Look for prior Trackbed work under the anchor key. **Read** the files; never trust stale memory.

1. **Manifest** — check `.trackbed/<key>/manifest.yml`. If it exists, read it to learn `anchor`, `format`, `roadmap_path`, and the other paths. A manifest means planning has run.
2. **Roadmap** — if no manifest, check for a roadmap anyway:
   - GSD mode → `.planning/ROADMAP.md`
   - Native mode → `.trackbed/<key>/roadmap.yml`

Decide the branch:

- **No roadmap and no manifest** → never planned. Invoke **trackbed-init** (passing the `anchor` and `key`) to build the roadmap and lock the format switch. When init returns, invoke **trackbed-orchestrate**.
- **Roadmap exists** (manifest and/or roadmap present, or the user chose "skip to orchestration") → skip init. Invoke **trackbed-orchestrate** directly. If a manifest is missing, `trackbed-orchestrate` will detect format from the files present and confirm with the user before writing one.

## Step 3 — Dispatch and get out of the way

- Hand control to the chosen internal skill(s): `trackbed-init` (only when nothing exists), then `trackbed-orchestrate`.
- Pass along the **anchor** and **key**. Each downstream skill re-reads the manifest and roadmap itself — the roadmap file is the single source of truth.
- Do not summarize, plan, or orchestrate on their behalf. Once dispatched, your job is done.

## Firewall reminder

Anything team-facing — Jira tickets, the PRD, ADRs — stays framework-neutral: plain domain language, **no** GSD/Trackbed vocabulary and **no** `.planning/` or `.trackbed/` paths. The internal skills enforce this; never instruct them otherwise.
