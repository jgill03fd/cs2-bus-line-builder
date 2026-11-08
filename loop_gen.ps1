# Generic district loop builder (bridge reads only; game keeps running).
# Fetches road edges around a centre, joins shortest drivable legs between four corner points into a simple cycle
# (edge-disjoint legs), then writes loop_<Name>.json with CW and CCW stop sets (shelter point 12 m on the right of each line's travel).
# Usage: loop_gen.ps1 -Name Example -Cx 0 -Cz 0 -R 700 -Corners "x1,z1;x2,z2;x3,z3;x4,z4"
param([Parameter(Mandatory)][string]$Name, [double]$Cx, [double]$Cz, [double]$R = 700, [Parameter(Mandatory)][string]$Corners, [int]$Stops = 8, [double]$Offset = 12.0, [switch]$TwoWayOnly, [switch]$UseCache)
. (Join-Path $PSScriptRoot 'roadkit.ps1') | Out-Null
$dir = Join-Path $PSScriptRoot 'out'; New-Item -ItemType Directory -Force $dir | Out-Null
# -UseCache: the road edges around a centre are fetched once and kept in out\edges_<x>_<z>_<r>.json (valid 6 h), so
# trying several corner sets on the same district does not re-read the roads every time.
$cacheFile = Join-Path $dir ("edges_{0}_{1}_{2}.json" -f [int]$Cx, [int]$Cz, [int]$R)
if ($UseCache -and (Test-Path $cacheFile) -and ((Get-Date) - (Get-Item $cacheFile).LastWriteTime).TotalHours -lt 6) {
  $raw = Get-Content $cacheFile -Raw | ConvertFrom-Json; "edges: cache hit ($cacheFile)"
} else {
  $raw = (RB get_network_edges @{ x = $Cx; z = $Cz; radius = $R; limit = 6000 }).result.edges
  if ($UseCache) { $raw | ConvertTo-Json -Depth 8 -Compress | Set-Content $cacheFile }
}
$edges = @()
foreach ($e in $raw) {
  if ($e.prefab -notmatch 'Pipe|Cable|Line|voltage|Track|Subway|Pedestrian|Alley|Taxiway|Runway|Airplane|Marker|Path') {
    $edges += [pscustomobject]@{ i = [long]$e.index; p = $e.prefab; s = [long]$e.startNode.index; e = [long]$e.endNode.index; x0 = [double]$e.curve[0].x; z0 = [double]$e.curve[0].z; x1 = [double]$e.curve[3].x; z1 = [double]$e.curve[3].z; len = [double]$e.length }
  }
}
"edges: $($edges.Count)"
$pos = @{}; $adj = @{}; $byId = @{}; $deg = @{}
# -TwoWayOnly: one-way edges are left out entirely, so every leg of the loop can be driven both ways.
if ($TwoWayOnly) { $edges = @($edges | ? { $_.p -notmatch 'Oneway' }); "two-way only: $($edges.Count) edges kept" }
foreach ($e in $edges) {
  $byId["$($e.i)"] = $e
  $pos["$($e.s)"] = @($e.x0, $e.z0); $pos["$($e.e)"] = @($e.x1, $e.z1)
  # undirected degree (a junction is 3+ roads, whatever their direction)
  $deg["$($e.s)"]++; $deg["$($e.e)"]++
  if (-not $adj["$($e.s)"]) { $adj["$($e.s)"] = @() }; $adj["$($e.s)"] += , @("$($e.e)", $e.len, "$($e.i)")
  if ($e.p -notmatch 'Oneway') { if (-not $adj["$($e.e)"]) { $adj["$($e.e)"] = @() }; $adj["$($e.e)"] += , @("$($e.s)", $e.len, "$($e.i)") }
}
function NearestNode($x, $z, $exclude = @()) { $best = $null; $bd = [double]::MaxValue; foreach ($k in $pos.Keys) { if ([int]$deg[$k] -lt 3 -or ($exclude -contains $k)) { continue }; $d =[math]::Pow($pos[$k][0] - $x, 2) + [math]::Pow($pos[$k][1] - $z, 2); if ($d -lt $bd) { $bd = $d; $best = $k } }; $best }
function ShortestPath($from, $to, $ban) {
  $dist = @{ $from = 0.0 }; $prev = @{}; $done = @{}
  while ($true) {
    $cur = $null; $cd = [double]::MaxValue
    foreach ($k in $dist.Keys) { if (-not $done[$k] -and $dist[$k] -lt $cd) { $cd = $dist[$k]; $cur = $k } }
    if (-not $cur -or $cur -eq $to) { break }
    $done[$cur] = 1
    foreach ($n in $adj[$cur]) { if ($ban.ContainsKey($n[2])) { continue }; $nd = $cd + $n[1]; if (-not $dist.ContainsKey($n[0]) -or $nd -lt $dist[$n[0]]) { $dist[$n[0]] = $nd; $prev[$n[0]] = @($cur, $n[2]) } }
  }
  if (-not $dist.ContainsKey($to)) { return $null }
  $nodes = @(); $eids = @(); $c = $to
  while ($c -ne $from) { $nodes += $c; $eids += $prev[$c][1]; $c = $prev[$c][0] }
  $nodes += $from; [array]::Reverse($nodes); [array]::Reverse($eids)
  @{ nodes = $nodes; edges = $eids }
}
# each corner gets its own junction: a corner never snaps onto a junction an earlier corner already uses
$cn = @()
foreach ($c in @($Corners.Split(';'))) { $t = $c.Trim(); if ($t -like 'id:*') { $node = $t.Substring(3) } else { $xy = $t.Split(','); $node = NearestNode ([double]$xy[0]) ([double]$xy[1]) $cn }; $cn += $node }
"corner nodes: $($cn -join ', ')"
$ln = New-Object System.Collections.ArrayList; $le = New-Object System.Collections.ArrayList
for ($i = 0; $i -lt $cn.Count; $i++) {
  $from = $cn[$i]; $to = $cn[($i + 1) % $cn.Count]
  $ban = @{}; foreach ($x in $le) { $ban[[string]$x] = 1 }
  $p = ShortestPath $from $to $ban
  if (-not $p) { "NO PATH leg $i ($from -> $to)"; exit 1 }
  for ($j = 0; $j -lt $p.nodes.Count - 1; $j++) { [void]$ln.Add($p.nodes[$j]) }
  foreach ($x in $p.edges) { [void]$le.Add($x) }
}
$uniqEdges = @($le | Select-Object -Unique).Count
"cycle nodes=$($ln.Count) edges=$($le.Count) unique_edges=$uniqEdges"
if ($uniqEdges -ne $le.Count) { "WARNING: repeated edges; loop is not simple"; exit 1 }
$sum = 0.0
for ($i = 0; $i -lt $ln.Count; $i++) { $a = $pos[$ln[$i]]; $b = $pos[$ln[($i + 1) % $ln.Count]]; $sum += $a[0] * $b[1] - $b[0] * $a[1] }
$builtCW = $sum -gt 0
function Pieces($nodes) {
  $pcs = @()
  for ($i = 0; $i -lt $nodes.Count; $i++) {
    $a = $nodes[$i]; $b = $nodes[($i + 1) % $nodes.Count]
    $eid = (@($adj[$a] | ? { $_[0] -eq $b })[0])[2]; $e = $byId[$eid]
    if ("$($e.s)" -eq "$a") { $ax = $e.x0; $az = $e.z0; $bx = $e.x1; $bz = $e.z1 } else { $ax = $e.x1; $az = $e.z1; $bx = $e.x0; $bz = $e.z0 }
    $pcs += [pscustomobject]@{ edge = [long]$eid; prefab = $e.p; ax = [double]$ax; az = [double]$az; bx = [double]$bx; bz = [double]$bz; len = [double]$e.len }
  }
  $pcs
}
function StopsFor($nodes) {
  $pcs = Pieces $nodes; $L = ($pcs | Measure-Object len -Sum).Sum; $step = $L / $Stops; $outS = @()
  for ($j = 0; $j -lt $Stops; $j++) {
    $idx = [math]::Floor(($j + 0.5) * $pcs.Count / $Stops); $t = 0.0; for ($q = 0; $q -lt $idx; $q++) { $t += $pcs[$q].len }; $t += $pcs[$idx].len / 2; $run = 0.0
    foreach ($pc in $pcs) {
      if ($t -le $run + $pc.len) {
        $f = ($t - $run) / $pc.len; $mx = $pc.ax + ($pc.bx - $pc.ax) * $f; $mz = $pc.az + ($pc.bz - $pc.az) * $f
        $dx = $pc.bx - $pc.ax; $dz = $pc.bz - $pc.az; $n = [math]::Sqrt($dx * $dx + $dz * $dz); $tx = $dx / $n; $tz = $dz / $n
        $rx = -$tz; $rz = $tx
        $outS += [pscustomobject]@{ n = $j + 1; edge = $pc.edge; prefab = $pc.prefab; mid = @([math]::Round($mx, 1), [math]::Round($mz, 1)); travel = @([math]::Round($tx, 3), [math]::Round($tz, 3)); shelter = @([math]::Round($mx + $rx * $Offset, 1), [math]::Round($mz + $rz * $Offset, 1)) }
        break
      }
      $run += $pc.len
    }
  }
  [pscustomobject]@{ length = [math]::Round($L, 1); stops = $outS }
}
$cwNodes = if ($builtCW) { @($ln) } else { @($ln)[($ln.Count - 1)..0] }
$ccwNodes = @($cwNodes)[($cwNodes.Count - 1)..0]
$cwS = StopsFor $cwNodes; $ccwS = StopsFor $ccwNodes
[pscustomobject]@{ name = $Name; cwLength = $cwS.length; ccwLength = $ccwS.length; cw = $cwS.stops; ccw = $ccwS.stops } | ConvertTo-Json -Depth 6 | Set-Content "$dir\loop_$Name.json"
"loop_$Name.json written: CW length $($cwS.length) m, CCW length $($ccwS.length) m"
"CW shelters: " + (($cwS.stops | % { "($($_.shelter[0]),$($_.shelter[1]))" }) -join ' ')
"CCW shelters: " + (($ccwS.stops | % { "($($_.shelter[0]),$($_.shelter[1]))" }) -join ' ')






