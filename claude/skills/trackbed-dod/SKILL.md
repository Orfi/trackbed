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
- **Verify the ledger; re-run only what's missing or stale.** You are a verifier of recorded evidence, not a re-executor. A check already satisfied by fresh, sha-pinned evidence passes on that evidence — regardless of who produced it. Re-running is the fallback, not the default. See **Evidence ledger and freshness** below.
- **Binary.** Each check is pass, fail, or waived-with-reason. No partial credit, no "probably fine."
- **Note discipline.** All check results go into the per-phase note under a `## DoD` heading. That section is **replaced** each run — never appended. Evidence accumulates in the note, not in the stamp.
- **Stamp discipline.** One compact line, **overwritten** each run — current truth only. See grammar below.
- **No silent passes.** A check that cannot be satisfied is never quietly dropped. A conditional check with nothing to verify is stamped `skipped (n/a)`; a check whose subject exists but has **no available verifier** is **red**, not skipped.

## Invocation

Called by `trackbed-orchestrate` with the outgoing phase id and the roadmap context (anchor, key, format) already in scope. May also be called directly:

> `/trackbed-dod <phase-id>` — runs a full dry-run; writes the stamp and note as normal.

Read the roadmap before running any check — never trust stale state.

## Resolving the verification commands

Checks 2, 3, 8, and 10 need project-specific commands. They come from the **verification contract** (spec §4.4) — an optional `verification:` block in the file recorded as `onboarding_path` in the manifest (falling back to `ONBOARDING.md`, `docs/ONBOARDING.md`, or `CONTRIBUTING.md`):

```yaml
verification:
  test: "dotnet test"
  build: "dotnet build"
  lint: "dotnet format --verify-no-changes"
  doc_check: "pwsh scripts/check-xml-docs.ps1 -Changed"
  project_dod_skill: /my-project-dod
```

**Assume none of it exists.** The block is optional, the file may be absent, and some repos have no build or test suite at all. Resolve each command in this order:

1. The `verification:` block, if present.
2. The repo's obvious convention — a lone `*.sln`, `package.json` scripts, a `Makefile` target.
3. **Ask the user once**, and offer to record the answer in the contract so the next gate is cheaper.

Never invent a command, and never guess twice. Then:

- **No such subject in the repo** (no test suite at all, no compiled language) → `skipped (n/a)`. Not a blocker; there is nothing to verify.
- **Subject exists but the command is unresolvable** → **red** (unverifiable). Say which command is missing in the stamp.

`project_dod_skill` absent means check 10 does not exist — never invent it.

## Evidence ledger and freshness

Gate-relevant tools are often run **before** you, independently — a code review that already executed format/build/test, a `/security-review` in an earlier turn, a doc check over the touched files. Re-running them is waste. Credit that work, but only when it is **recoverable and pinned to the current diff**.

**The ledger.** The `## DoD` table in the per-phase note carries a `sha` column: the commit each piece of evidence was produced at. `trackbed-orchestrate` appends entries as tools run during the phase; you read them, and you may backfill them yourself.

**Freshness — strict sha equality.** Evidence counts as fresh only when its `sha` equals `HEAD`. Any commit since invalidates it. No "probably still fine" — that is the assertion this gate exists to reject.

| Evidence state | Verdict |
|---|---|
| Ledger entry, `sha` == `HEAD` | **pass** — cite it: `pass (prior run @ a1b2c3d)` |
| Ledger entry, `sha` != `HEAD` | **stale** — re-run; red if it cannot be re-run |
| No entry, but a surviving artifact on disk (`.trx`, build log, review report) whose sha/mtime matches `HEAD` | **pass** — read it and **backfill** the ledger entry yourself |
| Only a conversational claim ("I ran the tests, they were green") | **not evidence** — ask for the summary line or the output path, which promotes it to a ledger entry. Failing that: re-run, red, or a human waiver. Never silent credit. |

Provenance is irrelevant — a hand-written entry and a skill-written one carry the same weight. Recoverability is what matters.

## The nine checks

Run in order. Each check must produce evidence; record it as you go. **Before running any check, consult the ledger** — if the check is already satisfied by fresh evidence, pass it on that evidence and move on.

### Check 1 — Phase `done:` criteria

Read the phase's `done:` field from the roadmap. Verify each criterion item-by-item against reality (files, tests, notes, tickets — whatever the criterion points at). The heart of the gate; never invent criteria.

- **Pass:** every criterion is demonstrably met with evidence.
- **Fail:** any criterion unmet or unverifiable.

### Check 2 — Tests

**Ledger first.** If the suite already ran at `HEAD` — directly, or inside a code review that executes it — pass on that evidence and cite it. A surviving result file (`.trx`, JUnit XML, coverage report) matching `HEAD` is equally good: read it and backfill the ledger.

Otherwise run the full suite using the resolved `test` command (see *Resolving the verification commands*). Read the actual output — do not rely on the exit code alone (exit code 0 is not evidence). Capture the real passed / failed / skipped counts.

- **Pass:** suite ran at `HEAD`, all tests pass, no new failures versus phase start.
- **Fail:** any test failure, any error, or any inability to run or recover the suite result.

Record the summary line verbatim.

### Check 3 — Build / lint clean

**Ledger first**, as with check 2 — a build/lint (or a code review that ran `dotnet format` / `clang-format` / `clang-tidy` and the build) already recorded at `HEAD` passes on that evidence. Otherwise run the resolved `build` and `lint` commands.

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

### Check 8 — Doc comments *(conditional on the diff, not on tooling)*

**The trigger is the diff:** this check applies whenever the phase touched `.cs` or `.cpp`/`.h` files. If it touched none, stamp `skipped (n/a)`. Tool availability does **not** decide whether the check applies — only how it is satisfied.

Satisfy it by the first of these that is available:

1. **Fresh ledger evidence** — a doc check or a language code review (e.g. `/orfi-kit-csharp-code-review`, `/orfi-kit-cpp-code-review`) already run at `HEAD`. Pass, cited.
2. **The doc skill** — `/orfi-kit-xml-docs` (C#) or `/orfi-kit-doxygen-docs` (C++), run over the phase's touched files.
3. **The repo's own checker** — e.g. `pwsh scripts/check-xml-docs.ps1 -Changed`, when the repo ships one.

**If the diff touched those file types and none of the three is available, the check is red — not skipped.** Undocumented public surface is a real gap; a missing verifier does not make it disappear. Say so plainly in the stamp (`blockers: doc comments unverifiable`) so a human can re-run with tooling or waive it deliberately.

Whichever route satisfied it, also:
- Apply the comment firewall over the diff: grep for narrative comments and for Trackbed/GSD vocabulary in code comments (`roadmap`, `phase`, `trackbed`, `gsd`, `gate`, `orchestrate`). Any match is a fail.
- Verify that **test files have no doc-comment blocks** — only regular comments where needed; a doc-comment block in a test file is a violation.

- **Pass:** every `public`/`protected`/`static` member touched by the diff carries a doc comment, firewall clean, no doc-comment blocks in test files.
- **Fail:** any missing doc comment, firewall hit, doc-comment block in a test file, or no available verifier.

### Check 9 — Security *(conditional)*

Satisfy it by the first available route:

1. **Fresh ledger evidence** — `/security-review`, or a language code review's security pass, already run at `HEAD`. Pass, cited.
2. **Run `/security-review`** over the phase diff.

If neither is available, stamp `skipped (unavailable)` — unlike check 8 there is no offline fallback, so this stays visible-but-non-blocking. Then:

1. **High / critical findings** must be fixed before the gate can be green.
2. **Medium and below** — record them in the phase note; they do not block.

- **Pass:** no high/critical findings (medium and below recorded, not blocking).
- **Fail:** any high or critical finding unresolved.

### Check 10 — Project DoD pass-through *(when declared)*

If the verification contract declares `project_dod_skill` (e.g. `/my-project-dod`), invoke it as one extra checklist item and record its verdict. This item does not exist if no such declaration is present — never invent it.

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
gate: green  (2026-07-18, 8/9 checks, 1 skipped: security unavailable)
gate: red    (2026-07-18, blockers: tests 43/47 failed, scope — see note)
gate: red    (2026-07-18, blockers: doc comments unverifiable — no verifier)
gate: waived (2026-07-18, reason: release deadline, by user)
```

- Date is today's date.
- Check count is the number of applicable checks — excluding only those stamped `skipped`. Skipped checks are named in the stamp. Checks passed on prior evidence still count as run.
- Test counts come from the real suite output — never fabricated.

**Stamp location (per format):**
- **Native mode** → overwrite the phase's `gate:` field in `.trackbed/<key>/roadmap.yml`.
- **GSD mode** → overwrite the `gate` column entry for this phase in `.trackbed/<key>/phase-jira.md`. Never touch GSD's `ROADMAP.md`.

## Per-phase note structure

Under the phase's notes section (or in `.trackbed/<key>/notes/<phase-id>.md`), replace the `## DoD` section entirely each run:

```markdown
## DoD

**Run:** <date>  **Result:** green | red | waived  **HEAD:** a1b2c3d

| # | Check | Result | sha | Evidence |
|---|-------|--------|-----|----------|
| 1 | done: criteria | pass | a1b2c3d | … |
| 2 | tests | pass | a1b2c3d | 47/47 passed (suite output line) |
| 3 | build/lint | pass (prior run) | a1b2c3d | csharp-code-review, this phase — 0 errors, 0 warnings |
| 4 | owes settled | pass | a1b2c3d | owes: [] |
| 5 | scope | pass | a1b2c3d | diff: 3 files, all within scope |
| 6 | commits | pass | a1b2c3d | 4 commits, format correct |
| 7 | planning files | pass | a1b2c3d | roadmap.yml, state.yml, viewer updated |
| 8 | doc comments | pass (prior run) | a1b2c3d | xml-docs skill — 12/12 members documented |
| 9 | security | skipped (unavailable) | — | /security-review not in session, no prior run |

**Blockers:** none  *(or list them)*
```

The `sha` column **is** the ledger. An entry whose sha != the `HEAD` line is stale and must be re-verified, never carried forward. `pass (prior run)` marks evidence you credited rather than produced; cite where it came from.

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
