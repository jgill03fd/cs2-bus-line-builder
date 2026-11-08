# Types a line name into the open line panel's title field, one key at a time, with the key list built from the string.
# Assumes the line panel is open. Its title position comes from the active UI profile (see ui-profile.ps1).
# Usage: type_name.ps1 -Name "RES(Crescent Croft) CONN CCW"
param([Parameter(Mandatory)][string]$Name)
$g = Join-Path $PSScriptRoot 'gamewin.ps1'
. (Join-Path $PSScriptRoot 'ui-profile.ps1')
$ui = Get-UiProfile
$punct = @{ '(' = 'shift+9'; ')' = 'shift+0'; ' ' = 'space' }
& $g hover $ui.line_title.x $ui.line_title.y -Scale 1.0 -Hold | Out-Null; Start-Sleep -Milliseconds 800
& $g click $ui.line_title.x $ui.line_title.y -Scale 1.0 -Hold | Out-Null; Start-Sleep -Milliseconds 700
& $g key -Keys ctrl+a -Hold | Out-Null
foreach ($ch in $Name.ToCharArray()) {
  if ($punct.ContainsKey([string]$ch)) { $k = $punct[[string]$ch] }
  elseif ($ch -cmatch '[A-Z]') { $k = "shift+$([string]$ch.ToString().ToLower())" }
  elseif ($ch -match '[a-z0-9]') { $k = [string]$ch }
  else { Write-Host "unsupported character '$ch' in name"; exit 1 }
  & $g key -Keys $k -Hold | Out-Null; Start-Sleep -Milliseconds 90
}
& $g key -Keys enter -Hold | Out-Null; Start-Sleep -Milliseconds 800
& $g hover $ui.parking_cursor.x $ui.parking_cursor.y -Scale 1.0 -Hold | Out-Null
Write-Host "typed '$Name'. Check the bridge name before moving on."





