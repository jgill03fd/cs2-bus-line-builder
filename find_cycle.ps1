# Finds a closed two-way road cycle near a point and prints loop_gen corners for it (bridge read, or the loop_gen edge cache).
# For every two-way edge the shortest cycle through it is edge length + shortest path between its ends without it.
# The cycle with a length in range whose centre is closest to the target wins. Corners are junction ids spaced along it.
# Usage: find_cycle.ps1 -Cx -300 -Cz -150 -R 450 [-MinLen 1000] [-MaxLen 2200]   (uses/creates out\edges_<x>_<z>_<r>.json)
param([double]$Cx, [double]$Cz, [double]$R = 450, [double]$MinLen = 1000, [double]$MaxLen = 2200, [int]$Corners = 4)
. (Join-Path $PSScriptRoot 'roadkit.ps1') | Out-Null
$dir = Join-Path $PSScriptRoot 'out'; New-Item -ItemType Directory -Force $dir | Out-Null
$cacheFile = Join-Path $dir ("edges_{0}_{1}_{2}.json" -f [int]$Cx, [int]$Cz, [int]$R)
if ((Test-Path $cacheFile) -and ((Get-Date) - (Get-Item $cacheFile).LastWriteTime).TotalHours -lt 6) { $raw = Get-Content $cacheFile -Raw | ConvertFrom-Json }
else { $raw = (RB get_network_edges @{ x = $Cx; z = $Cz; radius = $R; limit = 6000 }).result.edges; $raw | ConvertTo-Json -Depth 8 -Compress | Set-Content $cacheFile }
$EL = @(); $pos = @{}; $adj = @{}
foreach ($e in $raw) {
  if ($e.prefab -match 'Pipe|Cable|Line|voltage|Track|Subway|Pedestrian|Alley|Taxiway|Runway|Airplane|Marker|Path|Oneway') { continue }
  $s = "$($e.startNode.index)"; $t = "$($e.endNode.index)"
  $pos[$s] = @([double]$e.curve[0].x, [double]$e.curve[0].z); $pos[$t] = @([double]$e.curve[3].x, [double]$e.curve[3].z)
  $EL += [pscustomobject]@{ id = "$($e.index)"; s = $s; t = $t; len = [double]$e.length }
  if (-not $adj[$s]) { $adj[$s] = @() }; if (-not $adj[$t]) { $adj[$t] = @() }
  $adj[$s] += , @($t, [double]$e.length, "$($e.index)"); $adj[$t] += , @($s, [double]$e.length, "$($e.index)")
}
function Shortest($from, $to, $banEdge) {
  $dist = @{ $from = 0.0 }; $prev = @{}; $done = @{}
  while ($true) {
    $cur = $null; $cd = [double]::MaxValue
    foreach ($k in $dist.Keys) { if (-not $done[$k] -and $dist[$k] -lt $cd) { $cd = $dist[$k]; $cur = $k } }
    if (-not $cur -or $cur -eq $to) { break }
    $done[$cur] = 1
    foreach ($n in $adj[$cur]) { if ($n[2] -eq $banEdge) { continue }; $nd = $cd + $n[1]; if (-not $dist.ContainsKey($n[0]) -or $nd -lt $dist[$n[0]]) { $dist[$n[0]] = $nd; $prev[$n[0]] = $cur } }
  }
  if (-not $dist.ContainsKey($to)) { return $null }
  $path = @(); $c = $to; while ($c -ne $from) { $path += $c; $c = $prev[$c] }; $path += $from; [array]::Reverse($path)
  @{ len = $dist[$to]; nodes = $path }
}
$best = $null; $bd = [double]::MaxValue
foreach ($e in $EL) {
  $mx = ($pos[$e.s][0] + $pos[$e.t][0]) / 2; $mz = ($pos[$e.s][1] + $pos[$e.t][1]) / 2
  if ([math]::Sqrt([math]::Pow($mx - $Cx, 2) + [math]::Pow($mz - $Cz, 2)) -gt ($R * 0.7)) { continue }
  $p = Shortest $e.t $e.s $e.id
  if (-not $p) { continue }
  $L = $p.len + $e.len
  if ($L -lt $MinLen -or $L -gt $MaxLen) { continue }
  $gx = 0; $gz = 0; foreach ($nd in $p.nodes) { $gx += $pos[$nd][0]; $gz += $pos[$nd][1] }; $gx /= $p.nodes.Count; $gz /= $p.nodes.Count
  $d = [math]::Sqrt([math]::Pow($gx - $Cx, 2) + [math]::Pow($gz - $Cz, 2))
  if ($d -lt $bd) { $bd = $d; $best = @{ len = $L; nodes = $p.nodes; centre = @($gx, $gz) } }
}
if (-not $best) { Write-Host "no two-way cycle of $MinLen-$MaxLen m near ($Cx,$Cz) within $R m"; exit 1 }
$n = $best.nodes; $step = [math]::Max(1, [int][math]::Floor($n.Count / $Corners)); $ids = @(); for ($i = 0; $i -lt $Corners; $i++) { $ids += "id:$($n[[math]::Min($n.Count - 1, $i * $step)])" }
Write-Host ("cycle length {0:N0} m, {1} nodes, centre ({2:N0},{3:N0}), {4:N0} m from target" -f $best.len, $n.Count, $best.centre[0], $best.centre[1], $bd)
Write-Host ("loop_gen.ps1 -Name <Name> -Cx {0} -Cz {1} -R {2} -TwoWayOnly -UseCache -Corners `"{3}`"" -f [int]$Cx, [int]$Cz, [int]$R, ($ids -join ';'))


