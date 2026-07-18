# Trackbed DoD Gate & Hooks Amendment — Design

Date: 2026-07-18 · Author: Architect session · Status: approved for implementation
Source: `doc/design/notes/trackbed-feedback.md` (2026-07-11) + brainstorming session 2026-07-18.

## 1. Problem

The feedback's core finding: **Trackbed is a planning view, not a delivery gate.** "Phase done" is a
social contract, not a verified state; `phase-jira.md` drifts; `roadmap.html` goes stale; acceptance
criteria live disconnected from the phase record. The `/dod` skill the feedback references is foreign
(another machine/environment) and out of scope — Trackbed needs its own.

## 2. Decisions

- **D1 — Hooks amendment.** The "skills-only / no hooks" principle is consciously amended (2026-07-18).
  The core stays skills-first: markdown/YAML by convention, roadmap as single source of truth, re-read
  never trusted from memory, no required scripts or Python dependencies. **Hooks are permitted as an
  optional freshness layer only** (e.g. regenerating `roadmap.html` on planning-file writes). Hooks
  never enforce anything; Trackbed must remain fully usable with no hooks installed.
- **D2 — New skill `trackbed-dod`.** The sixth Trackbed skill. It gates the **phase transition**:
  when `trackbed-orchestrate` computes the next phase, the outgoing phase must carry a green (or
  waived) gate stamp produced by `trackbed-dod`. No stamp / red stamp → transition refused.
  Enforcement is by convention (orchestrate's instructions), not by hooks.
- **D3 — Nine universal checks** (§3), all evidence-based. Checks 8–9 are capability-conditional:
  they run only when their backing tool exists in the session; otherwise stamped
  `skipped (unavailable)` — visible, never a silent pass, never a blocker.
- **D4 — Project DoD pass-through.** If ONBOARDING declares a project-specific DoD skill (e.g. one
  that runs Snyk), `trackbed-dod` invokes it as one extra checklist item and records its verdict.
  Its internals are the project's business; absent a declaration, the item does not exist.
- **D5 — Waiver allowed.** A human may override a red gate; the override is recorded as
  `gate: waived (…)` — visible and auditable, never silent.
- **D6 — Native-first; GSD minimal.** Native mode: the stamp is a `gate:` field on the phase in
  `roadmap.yml`. GSD mode (slated for eventual removal): GSD's `ROADMAP.md` is never touched — the
  stamp lives as a `gate` column in the Trackbed-owned `.trackbed/<key>/phase-jira.md` table.
- **D7 — Grandfathering.** The gate applies only to transitions after the skill lands. Phases already
  closed are never retro-gated; orchestrate must not refuse to run on an old roadmap.
- **D8 — Anti-bloat rules.** The stamp is one compact line, **overwritten** each run — current truth
  only. Evidence and history go to the per-phase note. Criteria are referenced by pointer, never
  copied. The state file stays a fixed-shape digest with replaced (not appended) sections.
- **D9 — Out of scope.** PR creation/gating, `.trackbed/` strip automation, enforcement hooks,
  git-derived status sync (parked — independent of the gate).
- **D10 — Packaging.** Ships in all three agent variants (`claude/`, `copilot/`, `opencode/` — the
  latter two consume Claude's skill format), both installers (`install.sh`, `install.ps1`), README
  skill list, CHANGELOG.
- **D11 — Viewer.** `trackbed-view`'s `roadmap-template.html` renders the gate status per phase, so
  the stamp is visible in the artifact people actually read.

## 3. The nine universal checks

Every check produces **evidence, not assertion** (a count, a filename, a grep result — recorded in
the phase note). Every item is binary: pass, fail, or waived-with-reason. Unverifiable ⇒ red, not
"probably fine".

1. **Phase `done:` criteria** — each item from the roadmap's `done:` field verified against reality,
   item by item. The heart of the gate. The skill never invents criteria.
2. **Tests** — full suite actually run; real passed/failed/skipped counts captured; no new failures
   versus phase start. Exit code 0 is not evidence.
3. **Build/lint clean** — per ONBOARDING's verification commands.
4. **Owed gates settled** — anything the phase record flags as owed: ADR amendments filed, coverage
   thresholds met.
5. **Scope check** — the diff touches only what the phase scoped; adjacent changes reverted or
   explicitly noted.
6. **Commits clean** — repo commit format respected; no secrets in tracked files.
7. **Planning files current** — phase status, notes, phase↔ticket mapping updated; roadmap view
   regenerated (or hook confirmed to have done it).
8. **Doc comments** *(conditional)* — `/orfi-kit-xml-docs` (C#/XML-doc languages) or
   `/orfi-kit-doxygen-docs` (C++) run over the phase's touched files. Firewall on comments: no
   narrative comments and no Trackbed/GSD vocabulary ("phase", "roadmap", "gate", ticket-flow terms)
   in code comments — verified by grep over the diff. **Test files get no doc comments** — only
   regular informative comments where needed; doc-comment blocks in tests are a violation.
9. **Security** *(conditional)* — `/security-review` over the phase's diff. High/critical findings
   must be fixed; medium and below recorded in the phase note.

Plus, when declared (D4): **10. Project DoD** — the declared project skill's verdict.

## 4. Stamp grammar

One line, overwritten on every run:

```
gate: green  (2026-07-18, 9/9 checks, tests 47/47)
gate: green  (2026-07-18, 7/9 checks, 2 skipped: docs+security tools unavailable)
gate: red    (2026-07-18, blockers: tests 45/47, scope — see note)
gate: waived (2026-07-18, reason: <short reason>, by user)
```

Detail (per-check results, evidence, blocker list, waiver context) lives in the per-phase note,
replaced per run under a `## DoD` heading.

## 5. Delivery plan (ping-pong tasks)

- **T1 — Spec amendment.** `trackbed-spec.md`: amend the skills-only principle (D1), add the
  transition-gate principle (D2, D5–D8 in brief), add `gate:` to the native phase shape and the
  `gate` column to `phase-jira.md`'s description. CHANGELOG entry.
- **T2 — The skill + enforcement (claude variant).** New `claude/skills/trackbed-dod/SKILL.md`
  implementing §3–§4; `claude/skills/trackbed-orchestrate/SKILL.md` amended to require the stamp at
  transition (with D7 grandfathering).
- **T3 — Propagation + surfaces.** Viewer gate rendering (D11); copy/adapt skill + orchestrate change
  to `copilot/` and `opencode/`; both installers deploy the new skill; README skill list; CHANGELOG.

Each task is relayed, executed, reviewed by the Architect against this document, then the next is
issued. Commit format: `type: VERB: description` per repo history.
