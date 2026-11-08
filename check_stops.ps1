# Checks a planned loop against existing bus stops before any shelter is placed (bridge reads only).
# For every planned shelter point (CW and CCW) it reports stops within -Radius metres (default 20) and whether
# the stop already serves a line. Points with no stop nearby are clear. A nearby stop with no line can be reused;
# a nearby stop with a line is a clash (do not stack lines on one shelter).
# Also flags any planned piece on a one-way prefab.
# Usage: check_stops.ps1 -LoopJson .\out\loop_Example.json [-Radius 20]
param([Parameter(Mandatory)][string]$LoopJson, [double]$Radius = 20)
. (Join-Path $PSScriptRoot 'roadkit.ps1') | Out-Null
$loop = Get-Content $LoopJson -Raw | ConvertFrom-Json
$clash = 0; $reuse = 0; $oneway = 0
foreach ($set in 'cw', 'ccw') {
  foreach ($p in $loop.$set) {
    if ($p.prefab -match 'Oneway') { $oneway++; Write-Host "$set n$($p.n): one-way prefab ($($p.prefab)) on edge $($p.edge)" }
    $sx = [double]$p.shelter[0]; $sz = [double]$p.shelter[1]
    foreach ($s in @((RB get_transport_stops @{ x = $sx; z = $sz; radius = $Radius }).result.stops)) {
      $d = [math]::Round([math]::Sqrt([math]::Pow($s.position.x - $sx, 2) + [math]::Pow($s.position.z - $sz, 2)), 1)
      if (@($s.lines).Count) { $clash++; Write-Host "$set n$($p.n): CLASH stop $($s.index) at $d m, serves $(@($s.lines).Count) line(s)" }
      else { $reuse++; Write-Host "$set n$($p.n): reusable stop $($s.index) at $d m (no line)" }
    }
  }
}
Write-Host "summary: clashes $clash, reusable $reuse, one-way pieces $oneway. Move clashing points along their edge, then re-run."
