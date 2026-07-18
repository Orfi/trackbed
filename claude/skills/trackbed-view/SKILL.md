---
name: trackbed-view
description: Open the Trackbed roadmap viewer in the browser — a single self-contained HTML page that draws the roadmap three ways (phase board with color-coded status + Jira keys, rail strip, and dependency graph). Use whenever the user wants to see, open, visualize, or "show me" the roadmap for an epic or project. Regenerates the viewer from the live roadmap first so it always matches current state, then opens it. User-invocable.
---
# Trackbed View

Show the roadmap as a picture. You regenerate a single self-contained HTML viewer from the **live** roadmap, then open it in the browser. You read state; you never change the roadmap, status, tickets, or notes — for that, the user runs `trackbed`.

`<key>` is the epic key or project slug; it names `.trackbed/<key>/`. If the user didn't give one, infer it from a single existing `.trackbed/<key>/` directory, or ask.

## Hard rules

- **Read-only.** Never edit the roadmap, state, notes, or Jira from here. This skill only *projects* the roadmap.
- **Skills-only.** No build step, no server. You write one HTML file by convention and open it with the OS opener.
- **The viewer is a projection, never a second source of truth.** It is always rebuilt from the roadmap; if they ever disagree, the roadmap wins — regenerate.

## Step 1 — Locate the roadmap

1. Read `.trackbed/<key>/manifest.yml` to learn the `anchor`, `key`, `format`, and `roadmap_path`.
2. Read the live roadmap in the recorded format:
   - **native** → `.trackbed/<key>/roadmap.yml`
   - **gsd** → `.planning/ROADMAP.md` (+ `.trackbed/<key>/phase-jira.md` for the phase↔ticket mapping, if present)

## Step 2 — Regenerate the viewer

Build `.trackbed/<key>/roadmap.html` from the template bundled with this skill — `roadmap-template.html`, sitting next to this `SKILL.md`. Everything except the `DATA` object is generic and copied verbatim; rebuild only the `DATA` object from the live roadmap:

```js
const DATA = {
  anchor: "epic",            // or "project"
  key: "<key>",
  jiraBase: "",              // e.g. "https://acme.atlassian.net/browse" → clickable nodes/rows
  phases: [
    { id:"1", scope:"…", depends:[], done:"…", jira:"DEMO-101", status:"done|current|blocked|todo", owes:[], inserted:false, gate:"green (…)" },
    // one entry per phase, in roadmap order
  ]
};
```

- One entry per phase. Copy `id`, `scope`, `depends`, `done`, `owes` straight across.
- `jira`: the phase's key (native mode) or the mapping in `phase-jira.md` (gsd mode). Omit under a project anchor with no Jira.
- `status`: persist only `done | current | blocked | todo`. **Never write `next`** — the viewer computes "next" itself (first unblocked phase in dotted-segment id order).
- `gate`: optional — the DoD stamp written by `trackbed-dod`: `"green (…)"`, `"red (…)"`, or `"waived (…)"`. Omit or leave empty for ungated phases (grandfathered or not yet gated). The viewer renders a small colored badge per phase.
- `inserted: true` for decimal insertions.

Write the file, overwriting any previous copy. This keeps the picture exactly matching the roadmap every time it's opened.

## Step 3 — Open it

Open `.trackbed/<key>/roadmap.html` in a real browser. **Detect the OS first** and run the matching command — do not assume bash or a particular shell; use whatever shell the runtime gives you on this platform.

- **macOS** → `open "<abs-path>"` (uses the default browser; reliable).
- **Windows** → from PowerShell: `Start-Process "<abs-path>"`; from cmd: `start "" "<abs-path>"`; from Git Bash/WSL: `cmd.exe /c start "" "<win-path>"` (convert `/mnt/c/...` or POSIX paths to a Windows path / `file:///C:/...` URL first). Any of these opens the user's default browser.
- **Linux** → **prefer a real browser binary** over `xdg-open`. Try, in order, the first that exists: `google-chrome`, `chromium`, `firefox`, `brave-browser`, then **fall back** to `xdg-open "<abs-path>"`. `xdg-open` honours the desktop's `text/html` association, which is sometimes mis-set to a non-browser app (e.g. a chat client) — preferring an explicit browser avoids that. Launch detached (e.g. background it) so it doesn't block.

Use an **absolute path** (or a `file://` URL). **Always also print the absolute path** in your reply, so the user can open it manually when there's no GUI (headless box, SSH/remote session) or when the launch silently opens the wrong app. If generation in Step 2 failed for any reason, say so and still report the path.

## Relationship to other skills

- `trackbed-orchestrate` regenerates this same viewer automatically whenever it changes the roadmap or status (its Step 4 / Step 5). `trackbed-view` is the **on-demand** "open it now" front door — handy between orchestration turns.
- It is reached either directly by the user (`/trackbed-view <key>`) or from `trackbed` when the user just wants to look.
