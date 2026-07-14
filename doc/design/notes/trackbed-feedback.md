# Trackbed Feedback — 2026-07-11

## What works well

- The phase-jira mapping file is a clean, low-friction way to keep Jira keys tied to planning phases without leaking GSD terminology into team-facing artifacts
- The roadmap.html viewer (regenerated on demand) is a good separation — the data lives in markdown, the view is generated
- The "trackbed owns .planning" model is cleaner than having GSD and planning files mixed together

## Where it could be better

- The phase-jira.md is entirely manual — there's no enforcement that a commit references a valid phase, or that a phase status actually reflects reality. It drifts easily (was months stale in this session)
- No automatic gate between phase transitions. "Phase 12 done" is currently a social contract, not a verified state. A Trackbed phase shouldn't be closeable without the gate being green
- The roadmap.html has to be manually regenerated — if you forget, someone reads stale HTML
- No link back from the phase file to the actual acceptance criteria or owed gates (ADR amendments, coverage threshold, etc.) — those live in ONBOARDING.md and STATE.md, disconnected from the phase record

## Core gap

Trackbed is a planning view, not a delivery gate. It shows what should happen but doesn't enforce what must happen before phase close. The `/dod` skill partially fills that, but it's opt-in.

## Suggested improvements

- Auto-status sync from git: count commits referencing the Jira key, surface last commit date in the roadmap view
- Lightweight "phase-close checklist" embedded in the phase row that `/dod` writes to when it runs — so the phase record reflects verified completion, not assumed completion
- Roadmap.html auto-regenerated on any write to phase-jira.md (hook-driven)
- Phase acceptance criteria linked directly in the phase row, not scattered across ONBOARDING/STATE
