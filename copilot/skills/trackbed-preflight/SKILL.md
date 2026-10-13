---
name: trackbed-preflight
description: Prepare or refresh an epic/project or one Trackbed phase/story before planning. Reuse equivalent planning evidence and fill only missing requirements, dependency, architecture, current-behavior and acceptance-design checks. Does not implement, run DoD, or advance the roadmap.
---
# Trackbed Preflight

A lightweight starting check owned by Trackbed. Cover preparation once; do not add another ceremony when the selected planning flow already covers it. Use existing GSD/spec/plan/ADR artifacts when their scope and sources match. Do not invoke a repository's preflight skill or require any external framework.

Usage: `/trackbed-preflight <key> [phase <id> [story <issue-key>]]`. Key alone prepares the whole epic/project. With a phase, prepare that phase or its explicitly selected story. Codex uses `$trackbed-preflight` with the same arguments. This skill may be called by init, plan or orchestrate; it never authors the implementation plan.

## Boundaries

- Discover project instructions, requirements sources, architecture decisions, environment guidance and build/test commands through the manifest's existing pointers, project instructions, supplied links or bounded file discovery. No required repository folders, document names, languages, tracker fields, browser tool, credentials database or deployment platform. Only Trackbed's internal artifact locations are conventional.
- Read-only toward source, Git, infrastructure and issue trackers. Write only preparation notes. No worktree creation, branch sync, source edits, dependency installation, environment bootstrap, credential inventory, tests/builds, DoD or tracker transitions. A separately authorized executor owns those actions.
- Follow the project's actual requirements-source and readiness policies. Discover tracker field meanings rather than guessing IDs. Record status, estimate, sprint and labels if applicable; absent metadata is a blocker only when the project's policy makes it one. A project without Jira needs no Jira fields or access.
- No duplicate plans, copied evidence packets, global passed flag, forced mutation tests, adversarial reruns or repeated setup. Unknown facts stay unknown. Predict test failures; never label them observed RED.

## 1. Resolve the target and reuse what exists

1. Resolve `<key>` from the explicit argument or a single unambiguous Trackbed anchor. Read the manifest/roadmap/state if present. Epic/project preparation also works before a manifest or roadmap exists; do not create or lock a format here.
2. For a phase, resolve its exact id, scope, done criteria, dependencies and ticket mapping. A native `plan_targets:` or GSD `Plan targets:` roster enables separate story preparation. Validate a named story against that roster; ask when selection is ambiguous. Without a roster, prepare the whole legacy phase, including every linked story's applicable criteria. Never treat one story's preparation as its siblings' coverage.
3. Read relevant existing preparation artifacts first. An accepted GSD specification, plan or other planning-flow artifact can satisfy any check below. Cite its path/section and requirement revision instead of producing the same work again. Do not launch another framework just to collect a readiness stamp.
4. Compare target identity, authoritative requirements, applicable constraints and relevant code/config with the recorded sources. Refresh only missing or changed checks. Date or unrelated commit changes alone do not invalidate everything. A changed acceptance clause or constraint requires updating its bindings; changed source/test/config requires revisiting only affected discovery and commands. Reuse historical observed results only with their stated revision and scope.

## 2. Entire epic/project starting point

- Establish the objective, scope/non-goals and requirements source. For a Jira epic, read its current content and child summaries/dependency links. For a local project, use the user's agreed brief. Record source revision or a dated local source reference.
- Identify existing delivery, cross-cutting architectural constraints, relevant decision indexes, external dependencies, integration risks and acceptance/verification approach. Read only relevant documents; no exhaustive child implementation audit.
- Locate existing environment/run guidance and project tooling, or record what is not yet known. Reuse it across phases. Missing runtime setup does not prevent roadmap planning when it is documented as future work.
- Distinguish planning blockers (unclear objective or conflicting authoritative requirements) from execution blockers (an external contract, deployment or credentials needed later). A blocked child does not block planning unrelated work or the whole epic.
- Return these inputs to init's PRD/ADR/roadmap steps. Reuse its existing PRD/ADR reads; preflight does not create a second PRD, roadmap or implementation plan. Phase-specific source/test discovery belongs to the selected phase, not every story up front.

## 3. Selected phase/story starting point

Perform checks in this order, reusing matching artifacts:

1. **Requirements and readiness:** read the current authoritative story/local scope and preserve every acceptance clause before examining implementation. Record tracker revision and dependency facts where applicable. Conflicting requirement sources must be resolved, not silently merged. Check only actual project readiness policies; report observed facts without repairing tracker metadata.
2. **Architecture and contracts:** identify ownership boundaries, invariants, applicable decisions, APIs/events, consumers and compatibility/blast radius. Cite relevant documents or source. If no event impact is identified, say so. Existing decisions are reused; a real uncovered decision is routed through trackbed-adr using the chosen ADR mode, not invented here.
3. **Current behavior and tests:** inspect only relevant implementation/tests after requirements are captured. Cite paths/sections or lines. Classify clauses as missing, partial, exists-unproven, already-proven or unknown. Existing implementation is not automatically proof; unchanged accepted evidence may be reused with its limits.
4. **Acceptance design:** for each clause, state setup, action/input, observable semantic assertions, intended test location, required identity/data, and why the test would fail if behavior were absent. Audit bindings as DIRECT, PARTIAL, INDIRECT or UNBOUND. Cover every clause directly, or record the unresolved design gap. Browser evidence is needed for user-facing behavior according to project policy; use appropriate API/CLI/unit/integration/contract checks for other surfaces. Page loaded/no error alone does not prove behavior. Supporting regression/build/security/documentation checks are selected by the actual change, not blindly run now.
5. **Execution prerequisites:** reference known install/restore and run commands with their working directory, required role/tenant where relevant, affected deployment and isolated data/evidence destinations. Do not invent commands. Perform no setup here; a runtime readiness probe belongs immediately before a test that needs it, and only when existing readiness is absent/stale. Shared runtime and per-checkout dependencies are different; warn of an observed shared-deployment conflict rather than assuming isolated branches are deployed.
6. **Planning handoff:** give trackbed-plan the AC mapping, likely/confirmed/unknown change locations, test-first order, risks and commands. Preflight supplies planning inputs only. The implementation plan is authored once by trackbed-plan or adopted from the chosen planning tool. Preserve any project/user approval boundary before source implementation.

## 4. Compact persistence and verdict

Use an existing authoritative spec/plan when it already contains the checks: record just its reference, target/revision and remaining gaps in the anchor/phase note. Do not copy its contents into a new report. If there is no suitable artifact, record one compact `## Preflight` section:

- Epic/project: `.trackbed/<key>/preflight.md` (both storage modes, before/after init).
- Phase/story: the selected phase's existing note in its recorded format; identify the exact story in the section heading. If no phase note exists, use `.trackbed/<key>/notes/phase-<id>.md`. A phase may hold separate story sections; never overwrite sibling evidence.

Minimum contents: target; requirements source/revision and faithful clauses or exact artifact reference; constraints/dependencies and source references; current-behavior citations; clause-to-test semantic bindings and expected RED (phase/story only); commands/environment references; reused evidence; planning blockers; execution blockers; next action. Refresh the selected section instead of appending round-by-round narration. Point to it from the state digest/phase note where available. These are internal artifacts; do not leak their paths into tracker tickets.

Verdict: **ready for planning** when requirements are clear, necessary constraints are identified and (for a phase/story) every clause has DIRECT planned evidence; otherwise **blocked for planning**, with the specific gap. Execution-only blockers may coexist with ready-for-planning and must remain visible. A predicted RED is test intent, not test success. Preflight readiness is not implementation approval, DoD PASS or permission to change Git/Jira/deployments.

On resume, validate the existing reference and changed inputs; do not demand a new preflight file for an equivalent complete plan. Completed phases are not retro-gated. An old incomplete/current plan needs only the missing checks before further implementation.
