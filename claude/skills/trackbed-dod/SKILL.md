---
name: trackbed-dod
description: >-
  Internal Trackbed skill (invoked by trackbed-orchestrate at phase transition,
  or directly for a mid-phase dry-run). Runs the nine-check Definition-of-Done
  gate on the outgoing phase, records evidence in the per-phase note, and writes
  one compact gate stamp. Green or waived stamp required before orchestrate may
  advance to the next phase; red or missing stamp blocks the transition.
user-invocable: false
---
# Trackbed — DoD Gate

You are the phase-transition gate for one Trackbed roadmap. Your job is to verify the outgoing phase's Definition of Done with evidence — not assertion — and write a single compact stamp. You do not implement anything; you audit what the executor already did.

This is an internal skill. It is invoked by `trackbed-orchestrate` before it marks a phase `done` and advances. It may also be invoked directly with a phase id for a mid-phase dry-run — the stamp is always current truth and is always written, never suppressed.

## Non-negotiables

- **Evidence, not assertion.** Every check produces a count, a filename, a grep result, or a command summary — recorded in the per-phase note. "Looks fine" is not evidence; unverifiable = red.
- **Binary.** Each check is pass, fail, or waived-with-reason. No partial credit, no "probably fine."
- **Note discipline.** All check results go into the per-phase note under a `## DoD` heading. That section is **replaced** each run — never appended. Evidence accumulates in the note, not in the stamp.
- **Stamp discipline.** One compact line, **overwritten** each run — current truth only. See grammar below.
- **No silent passes.** Conditional checks that cannot run are stamped `skipped (unavailable)` — visible, never a blocker.

## Invocation

Called by `trackbed-orchestrate` with the outgoing phase id and the roadmap context (anchor, key, format) already in scope. May also be called directly:

> `/trackbed-dod <phase-id>` — runs a full dry-run; writes the stamp and note as normal.

Read the roadmap before running any check — never trust stale state.

## The nine checks

Run in order. Each check must produce evidence; record it as you go.

### Check 1 — Phase `done:` criteria

Read the phase's `done:` field from the roadmap. Verify each criterion item-by-item against reality (files, tests, notes, tickets — whatever the criterion points at). The heart of the gate; never invent criteria.

- **Pass:** every criterion is demonstrably met with evidence.
- **Fail:** any criterion unmet or unverifiable.

### Check 2 — Tests

Run the full test suite using the command(s) in ONBOARDING. Read the actual output — do not rely on the exit code alone (exit code 0 is not evidence). Capture the real passed / failed / skipped counts.

- **Pass:** suite runs, all tests pass, no new failures versus phase start.
- **Fail:** any test failure, any error, or any inability to run the suite.

Record the summary line verbatim.

### Check 3 — Build / lint clean

Run the build and lint commands from ONBOARDING.

- **Pass:** no errors, no new warnings.
- **Fail:** any error or new warning introduced by this phase.

Record the output summary verbatim.

### Check 4 — Owed gates settled

Read the phase's `owes:` list. Verify each item — ADR amendments filed, coverage thresholds met, anything the phase record flags as outstanding.

- **Pass:** `owes` is empty, or every listed item is demonstrably settled with evidence.
- **Fail:** any item unresolved.

### Check 5 — Scope check

Inspect the diff for this phase (e.g. `git diff <phase-start-sha>..HEAD` — use the phase's start point from the notes or roadmap). Verify that changes touch only what the phase's `scope:` field describes.

- **Pass:** diff is within scope.
- **Fail:** diff contains changes outside the phase scope. List them; do not silently accept them. Adjacent improvements spotted here are a fail until explicitly noted or reverted.

### Check 6 — Commits clean

Inspect the commits since phase start.

- **Pass:** every commit message follows the repo's commit format; no secrets, credentials, or sensitive data appear in tracked files (grep the diff for obvious patterns: API keys, passwords, tokens).
- **Fail:** any commit with a format violation, or any tracked file containing suspicious strings.

### Check 7 — Planning files current

Verify that the roadmap file, the state file, the phase↔ticket mapping (GSD mode: `phase-jira.md`; native: the `jira:` field), and the roadmap viewer (`.trackbed/<key>/roadmap.html`) are all up-to-date for this phase. In native mode also check that `state.yml` reflects the current position.

- **Pass:** all files match the actual phase outcome.
- **Fail:** any file is stale or missing an update for this phase.

### Check 8 — Doc comments *(conditional)*

**Run only when the phase touched `.cs` or `.cpp`/`.h` files AND the relevant skill is available in this session (`/orfi-kit-xml-docs` for C#, `/orfi-kit-doxygen-docs` for C++).** If the skill is unavailable, stamp this check `skipped (unavailable)` — never a blocker.

When the skill is available:
1. Run it over the phase's touched files.
2. Apply the comment firewall over the diff: grep for narrative comments and for Trackbed/GSD vocabulary in code comments (`roadmap`, `phase`, `trackbed`, `gsd`, `gate`, `orchestrate`). Any match is a fail.
3. Verify that **test files have no doc-comment blocks** — only regular comments where needed; a doc-comment block in a test file is a violation.

- **Pass:** doc comments present and correct on all touched members, firewall clean, no doc-comment blocks in test files.
- **Fail:** any missing doc comment, firewall hit, or doc-comment block in a test file.

### Check 9 — Security *(conditional)*

**Run only when `/security-review` is available in this session.** If unavailable, stamp this check `skipped (unavailable)` — never a blocker.

When available:
1. Run `/security-review` over the phase diff.
2. **High / critical findings** must be fixed before the gate can be green.
3. **Medium and below** — record them in the phase note; they do not block.

- **Pass:** no high/critical findings (medium and below recorded, not blocking).
- **Fail:** any high or critical finding unresolved.

### Check 10 — Project DoD pass-through *(when declared)*

If ONBOARDING declares a project-specific DoD skill (e.g. `project_dod_skill: /my-project-dod`), invoke it as one extra checklist item and record its verdict. This item does not exist if no such declaration is present — never invent it.

- **Pass:** the declared skill exits green.
- **Fail:** the declared skill exits red or errors.

## Waiver

A human may override a red gate. Waivers are recorded explicitly:

> Record `gate: waived (date, reason: <short reason>, by user)` and note the waiver context in the `## DoD` section of the phase note. Never grant a waiver yourself — only a human can.

When `trackbed-orchestrate` encounters a waived stamp it treats it as green and advances. The waiver is permanent for that run; re-running `trackbed-dod` overwrites it with a fresh check.

## Stamp grammar

Write exactly one of these lines, overwriting the previous stamp each run:

```
gate: green  (2026-07-18, 9/9 checks, tests 47/47)
gate: green  (2026-07-18, 7/9 checks, 2 skipped: docs+security unavailable)
gate: red    (2026-07-18, blockers: tests 43/47 failed, scope — see note)
gate: waived (2026-07-18, reason: release deadline, by user)
```

- Date is today's date.
- Check count is the number of applicable checks (i.e. excluding conditionals that were skipped). Skipped conditionals are listed in the stamp.
- Test counts come from the real suite output — never fabricated.

**Stamp location (per format):**
- **Native mode** → overwrite the phase's `gate:` field in `.trackbed/<key>/roadmap.yml`.
- **GSD mode** → overwrite the `gate` column entry for this phase in `.trackbed/<key>/phase-jira.md`. Never touch GSD's `ROADMAP.md`.

## Per-phase note structure

Under the phase's notes section (or in `.trackbed/<key>/notes/<phase-id>.md`), replace the `## DoD` section entirely each run:

```markdown
## DoD

**Run:** <date>  **Result:** green | red | waived

| # | Check | Result | Evidence |
|---|-------|--------|----------|
| 1 | done: criteria | pass | … |
| 2 | tests | pass | 47/47 passed (suite output line) |
| 3 | build/lint | pass | … |
| 4 | owes settled | pass | owes: [] |
| 5 | scope | pass | diff: 3 files, all within scope |
| 6 | commits | pass | 4 commits, format correct |
| 7 | planning files | pass | roadmap.yml, state.yml, viewer updated |
| 8 | doc comments | skipped (unavailable) | /orfi-kit-xml-docs not in session |
| 9 | security | skipped (unavailable) | /security-review not in session |

**Blockers:** none  *(or list them)*
```

## After the gate runs

1. Write the note (replace `## DoD` section).
2. Write the stamp (overwrite `gate:` in the correct location).
3. Report the result to `trackbed-orchestrate`:
   - **Green / waived** → orchestrate may advance. Quote the stamp line.
   - **Red** → quote the stamp line and list the blockers. Orchestrate refuses to advance until the executor resolves them and the gate is re-run.

## Grandfathering (D7)

Phases already closed (status: `done`) **before `trackbed-dod` existed** carry no `gate:` stamp. `trackbed-orchestrate` must not refuse to advance on a roadmap that predates this skill. When orchestrate is computing the next phase and a `done` phase has no stamp, treat it as if it passed — do not back-fill, do not re-open. Only transitions *after* this skill is installed are gated.

## Handoffs

- Invoked by **`trackbed-orchestrate`** at the moment it would mark a phase `done`.
- May be invoked directly by the user for a dry-run at any point during a phase.
- Reports result back to `trackbed-orchestrate`; does not advance the roadmap itself.
