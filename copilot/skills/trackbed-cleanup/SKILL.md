---
name: trackbed-cleanup
description: Use when a Trackbed epic or project roadmap is complete and its internal planning artifacts should be archived and removed before the final PR. Preview the selected paths, verify an external backup, and require confirmation before removal.
---
# Trackbed Cleanup

Finalize one completed roadmap. Archive its internal artifacts outside the repository, then remove only the confirmed paths from the working tree and stage tracked deletions. This is a user-invocable final lifecycle step, offered by orchestration after delivery is complete. It does not implement work, run DoD again, transition Jira, merge, publish, or rewrite Git history. Never commit automatically; leave changes for review and honor any no-commit instruction.

Usage: `/trackbed-cleanup <key> [backup <absolute-directory>]`. In Codex use `$trackbed-cleanup` with the same arguments. Additional repository-relative paths may be supplied explicitly by the user or in the selected manifest's optional `cleanup.paths` list. No other kit, helper-files pointer, or runtime dependency is required.

## 1. Verify completion and select paths

- Resolve the exact key and repository root. Read `.trackbed/<key>/manifest.yml`, its authoritative roadmap, state, story outcomes and DoD notes. Require a nonempty roadmap with every phase `done`, all in-scope stories settled, no outstanding `owes`, and green or explicitly human-waived gates. Retain DoD's existing grandfathering for phases closed before that gate existed; do not invent waivers or retro-gate them. No eligible next phase alone does not mean complete: blocked/todo/current work prevents cleanup.
- Missing or ambiguous completion evidence blocks cleanup. Return the precise gap to orchestration; do not mark phases done here. Do not rerun tests merely to archive already accepted evidence. Preserve the actual evidence revisions; cleanup cannot relabel old tests as having run at a later HEAD.
- Default removal scope is **only `.trackbed/<key>/`**, never the entire `.trackbed/` parent. Inventory other roadmaps and shared references before approving extra paths. In GSD mode, archive the roadmap/state/plan/note files referenced outside that directory too, but remove them only if explicitly selected and exclusively owned by this completed roadmap.
- Optional `cleanup.paths` are exact repository-relative paths, not globs or commands. Examples include a particular `.planning/phases/<directory>/` or a particular temporary spec. Entire `.planning/`, `docs/superpowers/`, or `.orfi-kits/` directories are opt-in, never defaults. Their existence is not proof of ownership. Reject unknown/shared ownership or any path needed by another roadmap or active session; narrow the selection instead. Do not edit other kits' pointers or require them to be installed.
- Preserve source, tests, PRDs, ADRs, user documents and other durable deliverables, even when nested under a proposed cleanup directory: narrow the deletion set or stop. Do not remove another roadmap, the repository root, `.git`, paths outside the repository, or symlinks/junctions/reparse points. Resolve and validate every target and ancestor; reject overlaps and traversal before recursive operations.

## 2. Prepare a reviewable preview

Read Git HEAD, branch, status and index. Build two explicit inventories: the removal inventory (every selected file, including hidden, ignored and untracked files, distinguishing tracked deletions from local-only removal) and the backup inventory (that inventory plus required referenced planning/evidence files outside the removal set). Archive-only references never become removal targets. Inspect and inventory those references now so the preview and later hash/count checks cover the complete backup. Tracked modifications or staged changes inside a removal target block cleanup until the user settles them; never force removal. Leave unrelated edits and the index outside selected paths untouched.

Use an explicitly supplied backup directory or the selected manifest's optional `cleanup.backup_root`. If neither exists, ask for an absolute destination. Do not consult `.orfi-kits/helper-files-root` or invent a helper-files convention. Resolve the destination outside the repository and all selected paths, reject links/reparse points along it, and create a new archive subdirectory identified by key, timestamp and a unique suffix. Never reuse or overwrite an archive.

Present repository/branch/HEAD, completion evidence, exact removal paths, archive-only references, external archive path and tracked/local-only/backup counts. State that removal deletes these files locally and stages tracked deletions; it leaves prior Git history intact. A prior request to implement this skill or finish a roadmap does not authorize cleanup of a consuming repository.

Require explicit confirmation of this exact destructive preview before copying or removing anything. A user declining leaves the repository unchanged. If paths, HEAD, index or target contents change after the preview, refresh it and obtain confirmation again.

## 3. Archive and verify before any removal

Copy every file in the backup inventory into the new archive, preserving repository-relative structure for files inside the repository. Include the selected manifest, final roadmap/state, notes, gate stamps, and referenced preparation/plans/evidence needed to recover the completion record. For references outside the repository, preserve their original absolute locations and evidence revisions; verify they remain accessible, or stop on missing required evidence rather than claiming a complete archive. External evidence is not a removal target. Never follow links while copying.

Write `cleanup-record.md` in the external archive with repository identity, branch/HEAD, completion/gate references, original paths, tracked/local-only classification, per-file SHA-256 hashes, external references, the confirmed removal list, and restoration instructions. Retain original result provenance without changing evidence timestamps or sha fields. Verify every copied file and hash against the backup inventory and source; backup counts must match that complete inventory, not just the removal count. An interrupted copy, missing file, mismatch, or unwritable destination stops the operation **before any deletion**. Keep the incomplete archive labelled incomplete; a retry uses a new directory.

## 4. Remove only the confirmed inventory

Recheck HEAD, index and the target inventory/hashes immediately before removal. If they differ, stop and refresh the preview. Once the complete archive is verified:

- Remove tracked paths using literal pathspecs, e.g. `git --literal-pathspecs rm -r -- <confirmed-path>`; never use force, broad `git add`, or a shell glob.
- Remove only the confirmed local-only files using the current shell's native literal-path operations. On Windows use `Remove-Item -LiteralPath` after verifying absolute targets remain inside the repository. Do not compose deletion across shells. Remove an emptied selected directory only after confirming no unexpected files remain.
- If any removal fails, stop and record precisely what was removed and what remains. Do not retry with force, discard other work, or claim completion. The verified archive remains available for recovery.

## 5. Verify and report; leave uncommitted

Read the final Git status and staged diff. Verify that the staged delta contains only the approved tracked deletions, unrelated pre-existing changes remain intact, the selected inventory is gone, and other roadmaps/durable artifacts remain. Record the actual result and any remaining paths in the external cleanup record, not in the directory just removed. Report the archive location, file counts, staged removals and blockers. Do not regenerate the removed planning state or invoke sync afterward.

Restoration uses the archive's original paths and hashes: compare the current working tree/index first and restore only the affected inventory without overwriting newer work; separately review/reverse only the cleanup's staged deletions. Never use a hard reset or broad checkout. No commit, push, merge or history rewriting is part of this skill. An already removed target is a no-op only when its matching verified archive/record can be recovered; otherwise report missing state instead of initializing a new roadmap or claiming cleanup succeeded.
