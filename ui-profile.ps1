# Screen positions for the game window, read from profiles\<name>.json next to this file.
# Choose a profile with the CS2_UI_PROFILE environment variable (default 1280x768).
# To add a resolution, copy profiles\1280x768.json to profiles\<width>x<height>.json and re-measure each position in the game.
$Global:UiProfileDir = $PSScriptRoot
function Get-UiProfile {
  $name = if ($env:CS2_UI_PROFILE) { $env:CS2_UI_PROFILE } else { '1280x768' }
  $path = Join-Path $Global:UiProfileDir "profiles\$name.json"
  if (-not (Test-Path $path)) { throw "UI profile not found: $path" }
  Get-Content $path -Raw | ConvertFrom-Json
}
