# Project Notes

## Purpose
This repo is now a multi-project host. Do not overwrite root `index.html` with a single game.

## Current Structure
- Root hub page: `index.html`
- Project manifest: `sites/projects.json`
- Individual projects live under: `sites/<project-slug>/`

## Existing Projects
- `sites/escape-room/`
- `sites/beach-defense/`
- `sites/harrisburg-track-hub/`
- `sites/cannon-beach-surf/`
- `sites/oracle-genie/`

## How To Add A New Project (Important)
1. Create folder: `sites/<new-project-slug>/`
2. Put project entry page at: `sites/<new-project-slug>/index.html`
3. Add one entry to `sites/projects.json` with:
   - `name`
   - `path` (example: `./sites/<new-project-slug>/`)
   - `description`
4. Commit and push. The root hub auto-lists from the manifest.

## GitHub Pages / Sharing
- Expected live base URL:
  - `https://tnqhdffrpf-cpu.github.io/beach-defense/`
- Project URLs are subpaths, e.g.:
  - `https://tnqhdffrpf-cpu.github.io/beach-defense/sites/escape-room/`

## Escape Room Notes
- Escape room now lives at `sites/escape-room/`.
- Uses local wall assets in `sites/escape-room/assets/walls/`.
- Includes story mode, safe keypad, door unlock, timer, and end screen.

## Important Constraint Found
- Current GitHub token can push normal commits but cannot update workflow files without `workflow` scope.
- If workflow edits are needed, either:
  - use a token with `workflow` scope, or
  - configure Pages directly in GitHub Settings.

## New Chat Bootstrap
In a new Codex chat, ask it to read this file first:
- `PROJECT_NOTES.md`
