# Contributing

This project is all rights reserved (see LICENSE). Contributions are accepted only with the copyright holder's agreement. By submitting a change you agree that it is licensed under the same terms and that the project owner may use, change and publish it.

## Workflow
- Do not push to `main`. Create a branch (for example `calibration-1920x1080`), push there, and open a pull request.
- The owner reviews and merges. Releases go out in phases, so a merge can wait for the next release.
- Keep each pull request small: one resolution or one fix.

## Adding a screen resolution
1. Copy `profiles/1280x768.json` to `profiles/<width>x<height>.json`.
2. Set `name` and `client` to match the game window.
3. Measure each position in the game and update its values. Do not commit screenshots.
4. Run the scripts with the profile selected, for example in PowerShell: `$env:CS2_UI_PROFILE = '1920x1080'`.

Keys the scripts use today: `screen_centre`, `shelter_pre_hover`, `parking_cursor`, `line_title`. The other keys are for manual steps and are not read by scripts yet.

## Checks before a pull request is merged
- Every `.ps1` file parses with no syntax errors.
- `check_stops.ps1` passes on a test loop (no clashes).
- A dry run of `build_line.ps1` prints the expected stops.
- In the game: one shelter and one line are built and verified on the bridge.

## Safety
- Do not commit city data, screenshots, saves, or bridge files.
- The CitiesIIAgentBridge mod is third-party and is not included here.
