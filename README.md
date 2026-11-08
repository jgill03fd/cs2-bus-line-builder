# cs2-bus-line-builder

PowerShell scripts that plan and build bus loops in **Cities: Skylines II** through the community
CitiesIIAgentBridge mod. They work out a perimeter loop for a district from the road network, place shelters
along it, and then build the line by clicking the game's Bus Line Tool.

This is experimental. It was built for one city and is not a general tool.

## What is included

| File | What it does |
|---|---|
| `loop_gen.ps1` | Reads road edges around a centre point, joins shortest legs between four corner points into a simple cycle, and writes `out\loop_<Name>.json` with clockwise (CW) and counter-clockwise (CCW) shelter points. |
| `place_shelters.ps1` | Places shelters one at a time. Each planned point gets a fallback list of nearby offsets, and the bridge checks for a new stop after every click. |
| `build_line.ps1` | Matches each planned point to its registered stop, then builds the line: start, add stops in order, close on the first stop. Dry run by default. |
| `roadkit.ps1` | Shared helpers: bridge calls (`RB`), camera, road lookups. |
| `gamewin.ps1` | Window helper: screenshots, hover, click, drag and key input on the game window. |

## Requirements

- Cities: Skylines II. Screen positions come from `profiles/<resolution>.json`; the default is `profiles/1280x768.json`. Set `CS2_UI_PROFILE` to use another. See CONTRIBUTING.md.
- PowerShell 7.
- The CitiesIIAgentBridge mod, installed separately. Get it from its own project page. This repository does not
  include it. Set `CS2_BRIDGE_DIR` to the folder that contains `bridge.ps1`.
- The Transportation palette must be open on the bus tab. The Bus Shelter tool and the Bus Line Tool must be
  selected by hand.

## Workflow (one district)

1. Plan the loop and check the output:
   `.\loop_gen.ps1 -Name Example -Cx -1500 -Cz 2580 -R 700 -Corners "x1,z1;x2,z2;x3,z3;x4,z4"`
2. Select the Bus Shelter tool, then place the CW and CCW shelters:
   `.\place_shelters.ps1 -LoopJson .\out\loop_Example.json -Set CW`
   `.\place_shelters.ps1 -LoopJson .\out\loop_Example.json -Set CCW`
3. Select the Bus Line Tool. Check the line (dry run), then build it:
   `.\build_line.ps1 -LoopJson .\out\loop_Example.json -Set CW`
   `.\build_line.ps1 -LoopJson .\out\loop_Example.json -Set CW -Go -Crops`
4. Name the line and set its fleet by hand in the line panel. The scripts do not do this.

## Known limits

- **Corner points are chosen by hand.** `loop_gen.ps1` snaps each corner to the nearest road junction. If a
  leg cannot be routed without reusing a road, it stops with `NO PATH`. Try different corner points. One
  district failed this way during testing.
- **The CCW loop can route much longer than the CW loop.** On one district the CCW line measured 4.7 mi against
  3.1 mi for the CW line. The routing has not been checked.
- **Clicks are not verified by reading the tooltip.** `build_line.ps1` pivots exactly on each registered stop.
  That worked for every stop in testing. `-Crops` saves a tooltip image per click, so you can check it
  afterwards. The first click after selecting the tool was lost once during testing, so check the first stop.
- **Fleet minimums differ by line.** A line's minimum can be 1, 2 or 3, and the script does not set fleets.
- **`roadkit.ps1` Refresh** calls `update-roads.ps1`. It needs `CS2_BRIDGE_DIR` set and the game running with the bridge answering. Its output goes to `roads-cache\`, which is not committed.

## Not included

- The CitiesIIAgentBridge mod and its source.
- Any city data, screenshots, reports or logs from the city this was built in.

## License

All rights reserved. Copyright (c) 2026 jgill03fd. See `LICENSE`.


## Working rules (learned in play)

These came from real mistakes during the build. The scripts assume them.

- **One action, then a check.** Take a screenshot after each click or key that changes the screen. Never chain several UI actions blind.
- **Check the title before renaming.** Open the line panel, read its length and stop count, and only then type a name. Overview rows move after every rename and scroll, so the row you clicked may not be the one you meant.
- **Scroll with the mouse wheel**, not the scrollbar thumb.
- **Verify on the bridge.** After each rename or build, confirm the name, stop count and completeness with get_transport_lines.
- **Bulldozer:** hover the target and confirm it is highlighted (the stop itself, not the road beside it) before clicking. Exit the tool with its own key (B), not right-click.
- **Stop placement:** use the placed-point file from place_shelters.ps1, not the planned points. The bridge search radius for stops must cover the whole loop (2 km).
- **Road class sets the offset:** Small roads at 6 m, Medium at 8 m, Large Divided at 12 m, learned per road type.
- **Checkpoint before removal:** Save before any demolish or line deletion.
- **Lines that leave the city** are named CITY TRANS N. Connectors into the city are RES(...), IND(...) or COM(...) CONN.
- **Clear the screen with the mouse Back button** (`gamewin.ps1 back -X2 4`). One press closes one panel layer, and one press drops the Bus Line Tool together with its palette. Repeated presses never open the pause menu. Escape does not drop the Bus Line Tool, so do not rely on it.
- **No clicks near the toolbar or panels while a build tool is active.** A click on the map with the Bus Line Tool selected can remove a stop from a route. Close panels and the overview first, then select the tool. A stray click removed a stop from a line once; the fix was to delete the line after a checkpoint and rebuild it from the placed points.





