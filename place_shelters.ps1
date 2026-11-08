# Places bus shelters for one loop written by loop_gen.ps1.
# For each planned kerb point: pivot the camera on it (zoom 120), hover and click the screen centre, then ask the
# bridge whether a stop now exists within 15 m. If not, try the next candidate (normal offsets 12/8/16/6/20 m,
# tangent shifts 0/+10/-10/+20/-20 m). The first candidate that adds a stop is kept.
# Prerequisite: the Bus Shelter tool is already selected in the Transportation palette (1280x768 client window).
# Usage: place_shelters.ps1 -LoopJson .\out\loop_Example.json -Set CW -Idx 1,2,3,4,5,6,7,8
param([Parameter(Mandatory)][string]$LoopJson, [Parameter(Mandatory)][ValidateSet('CW', 'CCW')][string]$Set, [int[]]$Idx = @(1..8))
. (Join-Path $PSScriptRoot 'roadkit.ps1') | Out-Null
$gw = Join-Path $PSScriptRoot 'gamewin.ps1'
$loop = Get-Content $LoopJson -Raw | ConvertFrom-Json
$stops = if ($Set -eq 'CW') { $loop.cw } else { $loop.ccw }
function CountNear($x, $z, $r) { @((RB get_transport_stops @{ x = $x; z = $z; radius = $r }).result.stops).Count }
$results = @()
foreach ($i in $Idx) {
  $s = $stops | ? { $_.n -eq $i } | Select-Object -First 1
  if (-not $s) { Write-Host "no planned stop $Set $i"; continue }
  $mx = [double]$s.mid[0]; $mz = [double]$s.mid[1]; $tx = [double]$s.travel[0]; $tz = [double]$s.travel[1]
  # right-hand normal of the line's travel direction (the game drives on the right; CW line = loop in clockwise order)
  $rx = -$tz; $rz = $tx
  $placed = $null
  :candidates foreach ($d in @(12, 8, 16, 6, 20)) { foreach ($a in @(0, 10, -10, 20, -20)) {
    $x = $mx + $rx * $d + $tx * $a; $z = $mz + $rz * $d + $tz * $a
    $before = CountNear $x $z 15.0
    RB set_camera @{ pivot = @{ x = $x; y = 575.0; z = $z }; zoom = 120.0 } | Out-Null
    Start-Sleep -Milliseconds 1500
    & $gw hover 620 370 -Scale 1.0 -Hold | Out-Null; Start-Sleep -Milliseconds 300
    & $gw hover 640 384 -Scale 1.0 -Hold | Out-Null; Start-Sleep -Milliseconds 900
    & $gw click 640 384 -Scale 1.0 -Hold | Out-Null; Start-Sleep -Milliseconds 1100
    & $gw hover 1100 150 -Scale 1.0 -Hold | Out-Null; Start-Sleep -Milliseconds 600
    if ((CountNear $x $z 15.0) -gt $before) { $placed = [pscustomobject]@{ x = [math]::Round($x, 1); z = [math]::Round($z, 1); normal = $d; tangent = $a }; break candidates }
  } }
  if ($placed) { Write-Host ("{0} {1}: placed at ({2},{3}) normal {4} m, tangent {5} m" -f $Set, $i, $placed.x, $placed.z, $placed.normal, $placed.tangent) }
  else { Write-Host ("{0} {1}: NOT PLACED near ({2},{3})" -f $Set, $i, $mx, $mz) }
  $results += [pscustomobject]@{ set = $Set; n = $i; placed = [bool]$placed; point = $placed }
}
& $gw restore | Out-Null
$outDir = Join-Path $PSScriptRoot 'out'; New-Item -ItemType Directory -Force $outDir | Out-Null
$results | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $outDir "placed_$Set.json")

