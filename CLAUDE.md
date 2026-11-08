# Instructions for Claude working in this repo

This is the cs2-bus-line-builder project (all rights reserved, see LICENSE). Read CONTRIBUTING.md before changing anything.

## At the start of every session
1. Read the latest comments on issue #1 ("Calibration 1920x1080: progress thread") before doing anything else.
2. Check open pull requests for review comments.
3. Tell the user what is new.

## Rules
- Never push to `main`. It is protected. Work on a branch and open a pull request.
- Calibration work goes on branch `calibration-1920x1080`. Files: `profiles/1920x1080.json` and `calibration/1920x1080.md`. Full steps: `calibration/START-HERE-1920x1080.md`.
- Do not commit screenshots, saves, city data, or bridge files. The CitiesIIAgentBridge mod is third-party and not part of this repo.
- Stop and ask the user before anything that needs approval: changing Windows or game display settings, opening or merging a pull request, or changing repo settings.

## Reporting
Comment on issue #1 when you start, when you push the branch, and when you open the pull request. Include the pull request link, the measured values, and anything that failed.
