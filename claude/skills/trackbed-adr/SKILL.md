---
name: trackbed-adr
description: Internal + shared ADR intake/create for Trackbed. Resolve the ADR location, scan and read existing Architecture Decision Records so planning respects them, and gap-fill a new ADR only when there is a genuine uncovered decision. Invoked inside trackbed-init (step 2, for an epic or project) and standalone by a story flow. Reading existing ADRs is the common case; creating one is the rare exception. Trigger whenever an epic, project, or story needs its recorded architecture decisions surfaced before planning.
---
# Trackbed — ADR Intake / Create

You handle Architecture Decision Records for Trackbed. Your job is **mostly reading**: surface the decisions already recorded so the roadmap (or a story's plan) respects them. ADRs almost always pre-exist. Creating a new one is the rare exception — only for a genuine, uncovered decision, and only with user approval.

You are an internal skill. You are invoked by `trackbed-init` (its step 2, after the PRD) and standalone by a story flow. You are never the user's front door — that is `trackbed`.

## Mode

Your caller passes an `adr_mode` (recorded in the manifest):

- **`read`** (default) — read existing ADRs and report the relevant decisions. **Create nothing.** Stop after Step 2.
- **`read-create`** — read existing ADRs, and additionally propose a new ADR for a genuine gap (Step 3), with user approval.

You are never invoked with `skip` — when ADRs are skipped, `trackbed-init` simply does not call you. If no mode is passed (e.g. a standalone story flow), default to `read` and ask the user before creating anything.

## Hard rules

- **ADRs are team-facing and durable.** They survive the final PR — they are *not* stripped like `.trackbed/` or `.planning/`. Keep them framework-neutral: plain domain and architecture language, **no** GSD/Trackbed vocabulary, **no** `.planning/` or `.trackbed/` paths, no phase↔ticket mapping.
- **Never assume an ADR path.** Resolve it from config; if unset, ask.
- **Reading is the job. Creating is the exception.** Default to writing nothing. Only propose a new ADR for a genuine gap, and never write it without explicit user approval.
- **Skills-only.** No scripts, no hooks. You scan, read, and write markdown by convention.

## Step 1 — Resolve the ADR location

Find where ADRs live for this epic/story. In order:

1. If you were invoked by `trackbed-init`, the manifest at `.trackbed/<key>/manifest.yml` (where `<key>` is the epic key or the project slug) may already carry `adr_path:`. Read it and use that.
2. Otherwise look for a configured ADR location (e.g. an `adr_path` in the manifest, or an obvious conventional folder such as `docs/adr/` or `docs/decisions/` already populated with `ADR-*.md`).
3. The location may be **this repo's `docs/`**, **another repo**, or a **local untracked folder**.

If the location is **unset or ambiguous, stop and ask the user** which one applies. Never guess a path and never invent files. Once resolved, if you were invoked by init, make sure `adr_path` is recorded in the manifest (init owns the write; report the resolved path back to it if it is missing).

## Step 2 — Scan and READ existing ADRs (the primary job)

This is the common case and your main deliverable.

1. List every `ADR-*.md` (or the repo's equivalent) at the resolved location.
2. **Read them** — do not just enumerate filenames. Understand each one: what decision was made, its status (proposed / accepted / superseded / deprecated), and its consequences.
3. Note the **global sequential numbering** already in use and the **highest number** taken, so any new ADR continues the sequence without collision.
4. Summarize for the caller the decisions relevant to the current epic or story, so downstream planning (the roadmap in `trackbed-init`, or a story's plan) respects them. Flag any ADR that constrains or contradicts the work in front of you.

If decisions implied by the current work are already covered by existing ADRs, you are **done — create nothing**. Say so explicitly.

## Step 3 — Gap-fill only (the rare exception, `read-create` mode only)

**Only enter this step when `adr_mode` is `read-create`.** In `read` mode you stop after Step 2 and create nothing.

Only reach this step when the current work clearly implies an architecture decision that **no existing ADR covers**.

1. Confirm the gap is genuine — re-check Step 2's ADRs before proposing anything. Do not duplicate or re-litigate a decision already recorded.
2. Propose **one** new ADR to the user. Use the next **global sequential** number: `ADR-NNNN.md` (continue from the highest existing number; zero-pad to match the repo's existing convention).
3. Use the conventional ADR format, framework-neutral:
   - **Title** — short decision statement
   - **Status** — proposed (then accepted once the user approves)
   - **Context** — the forces and constraints driving the decision
   - **Decision** — what was decided
   - **Consequences** — trade-offs, what becomes easier/harder
4. **User approves before you write.** Present the draft, get explicit go-ahead, then write the file at the resolved ADR location. Never auto-create.
5. Keep it clean of Trackbed/GSD jargon and internal paths — it is a durable, team-facing record.

## Output back to the caller

- The relevant recorded decisions and any constraints they impose on the current work.
- Whether you created a new ADR — and if so, its number, path, and title — or, far more often, that no new ADR was needed.
- The resolved `adr_path` (so `trackbed-init` can confirm it is recorded in the manifest).

Hand control back to whoever invoked you (`trackbed-init` continues to roadmap; a story flow continues to its plan). Do not drive execution yourself.
