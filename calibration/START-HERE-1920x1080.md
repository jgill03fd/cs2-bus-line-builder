# Transcript for the collaborator: calibrate 1920x1080 and push

Repo: https://github.com/jgill03fd/cs2-bus-line-builder

## Rules (read first)
1. Do not push to `main`. It is protected, so direct pushes are blocked. Work on a branch.
2. Push only these two files:
   - `profiles/1920x1080.json`
   - `calibration/1920x1080.md`
   Do not commit screenshots, saves, city data, or bridge files.
3. Stop and ask the owner before anything that needs approval:
   - changing Windows display settings or the game's display settings
   - opening a pull request, merging, or changing repo settings
   - anything not listed in this transcript
4. Do not edit or commit the bridge mod (CitiesIIAgentBridge). It is third-party.

## Step 1: Get the code
With git:
```
git clone https://github.com/jgill03fd/cs2-bus-line-builder.git
cd cs2-bus-line-builder
git checkout -b calibration-1920x1080
```
Without git: on GitHub, open the repo, click the branch dropdown, type `calibration-1920x1080`, and choose "Create branch from main".

## Step 2: Make the profile
Copy `profiles/1280x768.json` to `profiles/1920x1080.json`, then:
- set `"name"` to `"1920x1080"`
- set `"client"` to `{ "width": 1920, "height": 1080 }`
- replace every position value with a measured one. Do not keep the 1280x768 values.

Only four keys are used by the scripts today: `screen_centre`, `shelter_pre_hover`, `parking_cursor`, `line_title`. The rest are for manual steps.

Starting guesses, to measure and correct (1280x768 values scaled by x 1.5 and y 1.406):

| key | 1280x768 | starting guess at 1920x1080 |
|---|---|---|
| screen_centre | 640, 384 | 960, 540 |
| shelter_pre_hover | 620, 370 | 930, 520 |
| parking_cursor | 1100, 150 | 1650, 211 |
| line_title | 265, 59 | 398, 83 |

## Step 3: Measure in the game (window at 1920x1080)
Set the game window to 1920x1080. This changes display settings, so ask the owner first.

For each of the four keys:
- move the cursor to the point and check what the game shows
- take a full-size screenshot to check the position: `.\gamewin.ps1 shot -Out .\out\check.png -Scale 1.0`. Keep the image local. Never commit it.
- record the measured x and y

What each key needs:
- `screen_centre`: the centre of the map view. No panel should be under it.
- `shelter_pre_hover`: a point near the centre, off any panel and off the road lines.
- `parking_cursor`: an empty map area away from panels, for example the top right.
- `line_title`: open a bus line's panel (open the transport overview, click the line's magnifier), then click the title. It should open the name field.

## Step 4: Write the notes file
Create `calibration/1920x1080.md` from the template in `calibration/README.md`. Fill in the table with each key's measured x and y, and how you checked it.

## Step 5: Commit and push
With git, from the repo folder:
```
git add profiles/1920x1080.json calibration/1920x1080.md
git commit -m "Calibrate 1920x1080 profile"
git push -u origin calibration-1920x1080
```
Without git: on the `calibration-1920x1080` branch, click Add file > Create new file. Name it `profiles/1920x1080.json`, paste the JSON, and commit to `calibration-1920x1080`. Repeat for `calibration/1920x1080.md`.

## Step 6: Open a pull request
On GitHub: Pull requests > New pull request. Base: `main`. Compare: `calibration-1920x1080`. Title: "Calibration 1920x1080". In the description, list the four measured values and how each was checked. Then send the owner the link. The owner reviews and merges.

## Checks before you open the pull request
- `profiles/1920x1080.json` is valid JSON. In PowerShell: `Get-Content profiles\1920x1080.json -Raw | ConvertFrom-Json`
- Every position is measured. None is copied from 1280x768.
- Only the two files are in the commit. With git, `git status` shows nothing else.

## Report back to the owner
Send the pull request link, the four measured values, and anything that did not work.
