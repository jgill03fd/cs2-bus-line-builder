# Screen profiles

One JSON file per game window size, named `<width>x<height>.json` (for example `1920x1080.json`).

- `1280x768.json` is the reference profile. Start new profiles by copying it.
- Keep every key name. Change only `name`, `client` and the position values.
- Positions are in screen pixels of the game window at that size.
- The scripts read the profile named in the `CS2_UI_PROFILE` environment variable (default `1280x768`).
- Keys the scripts use: `screen_centre`, `shelter_pre_hover`, `parking_cursor`, `line_title`.
