# Builds one bus line (CW or CCW) on the shelters a loop has already placed.
# Each planned kerb point is matched to the registered stop within 15 m (bridge), then for each stop in order:
# pivot the camera exactly on the stop (zoom 10), hover the screen centre, and click it.
# The first click starts the route ("Create Route"), each later click adds a stop, and the last click is on the
# first stop ("Complete Route"). The camera is not moved by hand during the line.
# Prerequisites (manual): the Bus Line Tool is selected in the palette, and the camera is top-down (pitch 90).
# This script taps G until the bridge reports pitch 90.
# Without -Go it only prints the stops it would click (dry run).
# Usage: build_line.ps1 -LoopJson .\out\loop_Example.json -Set CW            (dry run)
#        build_line.ps1 -LoopJson .\out\loop_Example.json -Set CW -Go -Crops (builds it; saves tooltip crops)
param([Parameter(Mandatory)][string]$LoopJson, [Parameter(Mandatory)][ValidateSet('CW', 'CCW')][string]$Set, [switch]$Go, [switch]$Crops)
. (Join-Path $PSScriptRoot 'roadkit.ps1') | Out-Null
Add-Type -AssemblyName System.Drawing
$gw = Join-Path $PSScriptRoot 'gamewin.ps1'
$outDir = Join-Path $PSScriptRoot 'out'; New-Item -ItemType Directory -Force $outDir | Out-Null
$loop = Get-Content $LoopJson -Raw | ConvertFrom-Json
$points = if ($Set -eq 'CW') { $loop.cw } else { $loop.ccw }
$all = @((RB get_transport_stops @{ x = [double]$points[0].shelter[0]; z = [double]$points[0].shelter[1]; radius = 900.0 }).result.stops)
$stops = @()
foreach ($p in $points) {
  $px = [double]$p.shelter[0]; $pz = [double]$p.shelter[1]
  $best = $all | Sort-Object { [math]::Pow($_.position.x - $px, 2) + [math]::Pow($_.position.z - $pz, 2) } | Select-Object -First 1
  $d = if ($best) { [math]::Round([math]::Sqrt([math]::Pow($best.position.x - $px, 2) + [math]::Pow($best.position.z - $pz, 2)), 1) } else { -1 }
  if (-not $best -or $d -gt 15) { Write-Host "$Set $($p.n): no registered stop within 15 m of ($px,$pz). Place the shelter first."; exit 1 }
  $stops += [pscustomobject]@{ n = $p.n; id = $best.index; x = [double]$best.position.x; z = [double]$best.position.z; d = $d }
}
Write-Host ("$Set route in order: " + (($stops | % { "$($_.n)=stop $($_.id) (d $($_.d) m)" }) -join ', '))
if (-not $Go) { Write-Host 'Dry run: nothing clicked. Re-run with -Go to build the line.'; exit 0 }
for ($t = 0; $t -lt 6; $t++) { $pitch = (RB get_camera @{}).result.angle[1]; if ($pitch -ge 89.5) { break }; & $gw key -Keys g | Out-Null; Start-Sleep -Milliseconds 700 }
Write-Host "camera pitch $([math]::Round($pitch, 2)); zoom 10 from here on, camera not touched again until the route is complete"
function Click-Stop($st, $tag) {
  RB set_camera @{ pivot = @{ x = $st.x; y = 575.0; z = $st.z }; zoom = 10.0 } | Out-Null; Start-Sleep -Milliseconds 1300
  & $gw hover 620 370 -Scale 1.0 -Hold | Out-Null; Start-Sleep -Milliseconds 300
  & $gw hover 640 384 -Scale 1.0 -Hold | Out-Null; Start-Sleep -Milliseconds 1200
  if ($Crops) {
    $shot = Join-Path $outDir "tooltip_$Set$tag.png"; & $gw shot -Out $shot -Scale 1.0 | Out-Null
    $img = [System.Drawing.Image]::FromFile($shot); $bmp = New-Object System.Drawing.Bitmap 420, 260; $gr = [System.Drawing.Graphics]::FromImage($bmp)
    $gr.DrawImage($img, (New-Object System.Drawing.Rectangle 0, 0, 420, 260), (New-Object System.Drawing.Rectangle 430, 254, 420, 260), 'Pixel')
    $bmp.Save((Join-Path $outDir "tooltip_crop_$Set$tag.png")); $gr.Dispose(); $bmp.Dispose(); $img.Dispose()
  }
  & $gw click 640 384 -Scale 1.0 -Hold | Out-Null; Start-Sleep -Milliseconds 1100
}
Click-Stop $stops[0] '_1'
for ($i = 1; $i -lt $stops.Count; $i++) { Click-Stop $stops[$i] ('_' + ($i + 1)); Write-Host "clicked $Set stop $($i + 1) of $($stops.Count)" }
Click-Stop $stops[0] '_close'
& $gw hover 1100 150 -Scale 1.0 -Hold | Out-Null
Write-Host "closing click sent on stop 1. Check get_transport_lines for a complete line with $($stops.Count) stops, then name it and set its fleet by hand."


