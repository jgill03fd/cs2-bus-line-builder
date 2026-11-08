# Places bus shelters for one loop written by loop_gen.ps1.
# For each planned kerb point: pivot the camera on it (zoom 120), hover and click the screen centre, then ask the
# bridge whether a stop now exists within 15 m.
# Calibration: every loop stop records its road prefab (e.g. 'Medium Road'). The offsets that worked for that road
# type are kept in out\calibration.json and tried first, most successful first. The default grid (normal 12/8/16/6/20 m,
# tangent 0/+10/-10/+20/-20 m) is only tried after the learned ones miss. The first offset that adds a stop is kept
# and learned for next time.
# Prerequisite: the Bus Shelter tool is already selected in the Transportation palette (1280x768 client window).
# Usage: place_shelters.ps1 -LoopJson .\out\loop_Example.json -Set CW -Idx 1,2,3,4,5,6,7,8
param([Parameter(Mandatory)][string]$LoopJson, [Parameter(Mandatory)][ValidateSet('CW', 'CCW')][string]$Set, [int[]]$Idx = @(1..8))
. (Join-Path $PSScriptRoot 'roadkit.ps1') | Out-Null
$gw = Join-Path $PSScriptRoot 'gamewin.ps1'
$outDir = Join-Path $PSScriptRoot 'out'; $tag = [IO.Path]::GetFileNameWithoutExtension($LoopJson); New-Item -ItemType Directory -Force $outDir | Out-Null
$calPath = Join-Path $outDir 'calibration.json'
# calibration: road prefab -> entries of { normal, tangent, hits }
$cal = @{}
if (Test-Path $calPath) { $raw = Get-Content $calPath -Raw | ConvertFrom-Json; foreach ($p in $raw.PSObject.Properties) { $cal[$p.Name] = @($p.Value) } }
function Candidates([string]$prefab) {
  $keys = New-Object System.Collections.ArrayList
  if ($cal.ContainsKey($prefab)) { foreach ($e in ($cal[$prefab] | Sort-Object -Property hits -Descending)) { [void]$keys.Add("$($e.normal),$($e.tangent)") } }
  # road class from the prefab name (the bridge does not expose road width): small roads sit closer to the centre line'
  $normals = if ($prefab -match 'Small') { 8, 6, 10 } elseif ($prefab -match 'Divided|Large') { 12, 10, 14 } else { 8, 12, 10 }
  foreach ($d in $normals) { foreach ($a in 0, 10, -10) { [void]$keys.Add("$d,$a") } }
  $keys | Select-Object -Unique | Select-Object -First 8
}
function Learn([string]$prefab, [int]$d, [int]$a) {
  if (-not $cal.ContainsKey($prefab)) { $cal[$prefab] = @() }
  $hit = @($cal[$prefab] | ? { $_.normal -eq $d -and $_.tangent -eq $a })
  if ($hit.Count) { $hit[0].hits++ } else { $cal[$prefab] = @($cal[$prefab]) + [pscustomobject]@{ normal = $d; tangent = $a; hits = 1 } }
  $cal | ConvertTo-Json -Depth 4 | Set-Content $calPath
}
function CountNear($x, $z, $r) { @((RB get_transport_stops @{ x = $x; z = $z; radius = $r }).result.stops).Count }
$loop = Get-Content $LoopJson -Raw | ConvertFrom-Json
$stops = if ($Set -eq 'CW') { $loop.cw } else { $loop.ccw }
$results = @()
foreach ($i in $Idx) {
  $s = $stops | ? { $_.n -eq $i } | Select-Object -First 1
  if (-not $s) { Write-Host "no planned stop $Set $i"; continue }
  $prefab = [string]$s.prefab
  $mx = [double]$s.mid[0]; $mz = [double]$s.mid[1]; $tx = [double]$s.travel[0]; $tz = [double]$s.travel[1]
  # right-hand normal of the line's travel direction (the game drives on the right; CW line = loop in clockwise order)
  $rx = -$tz; $rz = $tx
  $placed = $null; $tries = 0
  :candidates foreach ($key in (Candidates $prefab)) {
    $d = [int]$key.Split(',')[0]; $a = [int]$key.Split(',')[1]; $tries++
    $x = $mx + $rx * $d + $tx * $a; $z = $mz + $rz * $d + $tz * $a
    $before = CountNear $x $z 15.0
    RB set_camera @{ pivot = @{ x = $x; y = 575.0; z = $z }; zoom = 120.0 } | Out-Null
    Start-Sleep -Milliseconds 1500
    & $gw hover 620 370 -Scale 1.0 -Hold | Out-Null; Start-Sleep -Milliseconds 300
    & $gw hover 640 384 -Scale 1.0 -Hold | Out-Null; Start-Sleep -Milliseconds 900
    & $gw click 640 384 -Scale 1.0 -Hold | Out-Null; Start-Sleep -Milliseconds 1100
    & $gw hover 1100 150 -Scale 1.0 -Hold | Out-Null; Start-Sleep -Milliseconds 600
    if ((CountNear $x $z 15.0) -gt $before) { $placed = [pscustomobject]@{ x = [math]::Round($x, 1); z = [math]::Round($z, 1); normal = $d; tangent = $a }; Learn $prefab $d $a; break candidates }
  }
  if ($placed) { Write-Host ("{0} {1} [{2}]: placed at ({3},{4}) normal {5} m, tangent {6} m, after {7} tries" -f $Set, $i, $prefab, $placed.x, $placed.z, $placed.normal, $placed.tangent, $tries) }
  else { Write-Host ("{0} {1} [{2}]: NOT PLACED near ({3},{4}) after {5} tries" -f $Set, $i, $prefab, $mx, $mz, $tries) }
  $results += [pscustomobject]@{ set = $Set; n = $i; prefab = $prefab; placed = [bool]$placed; tries = $tries; point = $placed }
}
& $gw restore | Out-Null
$results | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $outDir "$tag.placed_$Set.json")


