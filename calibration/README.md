# Calibration notes

One Markdown file per profile, named to match it (for example `1920x1080.md`). Record how each position was measured. Do not commit screenshots.

## Template

- Profile: `<width>x<height>`
- Date:
- Game version (shown in the launcher or the game's options):
- Window size and display scaling (Windows display settings):
- Measured by:

| Key | x | y | How measured (what the cursor showed) |
|---|---|---|---|
| screen_centre | | | |
| shelter_pre_hover | | | |
| parking_cursor | | | |
| line_title | | | |
| line_panel_close | | | |
| transport_toolbar | | | |
| bus_shelter_tool | | | |
| bus_line_tool | | | |
| palette_close | | | |
| overview_first_magnifier | | | |

## Checks done
- [ ] Hover over `shelter_pre_hover` and `screen_centre` gives the expected tooltip
- [ ] `line_title` opens the line panel title when clicked
- [ ] A dry run of `build_line.ps1` with `CS2_UI_PROFILE` set prints the expected stops

## Notes
