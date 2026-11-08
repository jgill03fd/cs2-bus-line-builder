# roadkit.ps1 — one tested toolkit for every road job. Load once per command:
#   . "roadkit.ps1 (this folder)"
# Everything PRINTS with Write-Host (never capture it in a variable to read results).
# Typical job (5 lines):
#   Look -1700 200; Stop-Game
#   $s = @( (Road HW1 (NodeRef 221127 -1742 387) (Pt -1738 215) -Ctl -1751,262), (Road HW1 (Pt -1738 215) (OnZ (Edge 222416 -1700 170) 127)) )
#   Run $s -Dry            # every step previewed with a $1 cap (fits / rejected + what it hits)
#   Run $s                 # real build, sequential, stops at the first failure
#   Verify -1700 200 300   # dead ends + 1-node gaps in the area; then Route / Water as needed; Go-Game

# Folder that holds bridge.ps1 (the community CitiesIIAgentBridge mod). Set CS2_BRIDGE_DIR or edit here.
$Script:BridgeDir = $env:CS2_BRIDGE_DIR
$Script:RoadData = $PSScriptRoot

# ---- prefab ids (this city session) ----
$Script:PF = @{ HW1 = 15912; HW2 = 15913; HW3 = 15914; HW4 = 15915; HW5 = 15916; HW2way4 = 15944
  XL = 15911; LargeDiv = 15910; Medium = 15905; SmallRoad = 15901; SmallOneway = 15902; SmallOneway1 = 15903; SmallOneway3 = 15904
  PipeSmall = 15971; PipeLarge = 15980; HV = 15968 }
foreach ($k in $Script:PF.Keys) { Set-Variable -Name $k -Value $Script:PF[$k] -Scope Script }

# ---- bridge call, in-process (no new pwsh per call) ----
function RB([string]$cmd, $obj) {
  $json = if ($null -eq $obj) { '{}' } else { $obj | ConvertTo-Json -Compress -Depth 12 }
  Push-Location $Script:BridgeDir
  try { $raw = & .\bridge.ps1 -Command $cmd -ArgsJson $json } finally { Pop-Location }
  ($raw | Out-String) | ConvertFrom-Json -Depth 30 }
function Wait-Op($id) { for ($i = 0; $i -lt 60; $i++) { $r = (RB get_operation @{ id = $id }).result; if ($r.status -in 'complete', 'failed', 'interrupted') { return $r }; Start-Sleep -Milliseconds 800 }; $r }
function Wait-Batch($id) { for ($i = 0; $i -lt 90; $i++) { $r = (RB get_batch @{ id = $id }).result; if ($r.status -notin 'queued', 'running', 'validating', 'applying') { return $r }; Start-Sleep -Milliseconds 800 }; $r }

# ---- game control ----
# Player rule (2026-11-07): never pause the city from scripts; it runs at the speed in the bridge's run_speed.txt.
# Pause only by hand, for something broken or a severe population dip.
function Stop-Game { Write-Host 'Stop-Game ignored: the city keeps running (player rule)' }
function Go-Game([int]$speed = 2) { $s = $(if ($speed -eq 3) { 4 } else { $speed })   # bridge: 0,1,2,4 (4 = in-game speed 3)
  $r = RB set_simulation_speed @{ speed = $s }; if ($r.ok) { Write-Host "game speed $speed" } else { Write-Host "SPEED FAILED: $($r.error)" } }
function Look([double]$x, [double]$z, [double]$zoom = 900) { RB set_camera @{ pivot = @{ x = $x; y = 575.0; z = $z }; zoom = $zoom } | Out-Null; Start-Sleep -Milliseconds 1800 }
function Save([string]$label) { $r = RB save_checkpoint @{ label = $label }; if ($r.result.id) { $null = Wait-Op $r.result.id }; Start-Sleep -Seconds 4; Write-Host "checkpoint '$label' ok=$($r.ok)" }
function Snap([double]$scale = 0.7) { & (Join-Path $PSScriptRoot 'gamewin.ps1') shot -Scale $scale | Out-Null; Write-Host 'screenshot saved (game_shot.png in the current folder)' }

# ---- lookups (roads incl. Road Builder custom roads; utilities/tracks filtered) ----
function Is-Road($e) { $e.prefab -notmatch 'Pipe|Cable|Line|voltage|Track|Subway|Pedestrian|Alley|Taxiway|Runway|Airplane|Marker' }
function Edges([double]$x, [double]$z, [double]$r = 150, [switch]$All, [switch]$Show) {
  $es = (RB get_network_edges @{ x = $x; z = $z; radius = $r; limit = 6000 }).result.edges
  if (-not $All) { $es = $es | ? { Is-Road $_ } }
  if ($Show) { $deg = @{}; $es | % { foreach ($n in "$($_.startNode.index)", "$($_.endNode.index)") { $deg[$n]++ } }
    $es | Sort-Object { $_.curve[0].z } | % { Write-Host ("{0,-7} {1,-30} ({2,5},{3,5},y{4})->({5,5},{6,5},y{7}) n{8}[{9}]->n{10}[{11}] len{12}" -f $_.index, ($_.prefab -replace 'Highway ', 'HW '), [int]$_.curve[0].x, [int]$_.curve[0].z, [int]$_.curve[0].y, [int]$_.curve[3].x, [int]$_.curve[3].z, [int]$_.curve[3].y, $_.startNode.index, $deg["$($_.startNode.index)"], $_.endNode.index, $deg["$($_.endNode.index)"], [int]$_.length) } }
  $es }
function Edge([long]$id, [double]$x, [double]$z, [double]$r = 250) { $e = (RB get_network_edges @{ x = $x; z = $z; radius = $r; limit = 6000 }).result.edges | ? { $_.index -eq $id } | Select -First 1; if (-not $e) { Write-Host "EDGE $id NOT FOUND near ($x,$z)" }; $e }
# Point refs. ALWAYS prefer ids taken from edge data over coordinate searches.
function Pt([double]$x, [double]$z) { @{ x = $x; z = $z } }
function NodeRef([long]$id, [double]$x, [double]$z) { $n = (RB get_network @{ x = $x; z = $z; radius = 30.0 }).result.nodes | ? { $_.index -eq $id } | Select -First 1
  if (-not $n) { Write-Host "NODE $id NOT FOUND near ($x,$z)"; return $null }; @{ x = [double]$n.position.x; z = [double]$n.position.z; index = [long]$n.index; version = [int]$n.version } }
function StartOf($e) { @{ x = [double]$e.curve[0].x; z = [double]$e.curve[0].z; index = [long]$e.startNode.index; version = [int]$e.startNode.version } }
function EndOf($e) { @{ x = [double]$e.curve[3].x; z = [double]$e.curve[3].z; index = [long]$e.endNode.index; version = [int]$e.endNode.version } }
function OnT($e, [double]$t) { @{ x = [double]($e.curve[0].x + ($e.curve[3].x - $e.curve[0].x) * $t); z = [double]($e.curve[0].z + ($e.curve[3].z - $e.curve[0].z) * $t); index = [long]$e.index; version = [int]$e.version; curvePosition = [math]::Round($t, 3) } }
function OnZ($e, [double]$z) { OnT $e (($e.curve[0].z - $z) / ($e.curve[0].z - $e.curve[3].z)) }
function OnX($e, [double]$x) { OnT $e (($x - $e.curve[0].x) / ($e.curve[3].x - $e.curve[0].x)) }

# ---- steps ----  ($pf may be a name like HW2 / SmallOneway3 or a numeric id)
function PfId($pf) { if ($pf -is [string] -and $Script:PF.ContainsKey($pf)) { return [int]$Script:PF[$pf] }; [int]$pf }
function Road($pf, $start, $end, [double[]]$Ctl, [double]$Elev = [double]::NaN, [int]$Cost = 20000) {
  $a = @{ prefabIndex = (PfId $pf); prefabVersion = 1; start = $start; end = $end; maxCost = $Cost }
  if ($Ctl) { $a.control = @{ x = $Ctl[0]; z = $Ctl[1] } }; if (-not [double]::IsNaN($Elev)) { $a.elevation = $Elev }
  @{ kind = 'road'; label = "road $pf ($([int]$start.x),$([int]$start.z))->($([int]$end.x),$([int]$end.z))"; args = $a } }
function Pipe($pf, $start, $end, [int]$Cost = 20000) { $s = Road $pf $start $end -Cost $Cost; $s.kind = 'network'; $s.label = $s.label -replace '^road', 'network'; $s }
function Upgrade($e, $pf, [int]$Cost = 20000) { @{ kind = 'upgrade'; label = "upgrade $($e.index) $($e.prefab) -> $pf"; args = @{ prefabIndex = (PfId $pf); prefabVersion = 1; index = [long]$e.index; version = [int]$e.version; maxCost = $Cost }; edge = $e } }
function Remove($e) { @{ kind = 'demolish'; label = "remove $($e.index) $($e.prefab)"; args = @{ index = [long]$e.index; version = [int]$e.version } } }

function Show-Result($label, $r) {
  $hits = ($r.placementErrors | ? { $_.flags -notmatch 'Create' -and $_.prefab.index } | % { "$($_.prefab.index)@$($_.index)" } | Select -Unique) -join ';'
  $fit = ($r.status -eq 'complete') -or ($r.error -eq 'cost_exceeds_budget')
  Write-Host ("  {0,-8} {1}  cost {2} {3} {4}" -f $(if ($fit) { 'OK' } else { 'REJECTED' }), $label, $r.previewCost, $r.error, $(if ($hits) { "hits $hits" } else { '' }))
  $fit }
# Run a list of steps. -Dry previews each one alone with a $1 cap. Real run stops at the first failure.
# NOTE: in a real run, later steps that point at nodes created by earlier steps must use Pt() at the same coordinates;
# Run re-resolves Pt() endpoints to the node now sitting there (within 2 m), so chains connect.
function Resolve($p) { if ($p.index) { return $p }; $n = (RB get_network @{ x = $p.x; z = $p.z; radius = 2.0 }).result.nodes | Select -First 1; if ($n) { @{ x = [double]$n.position.x; z = [double]$n.position.z; index = [long]$n.index; version = [int]$n.version } } else { $p } }
function Run($steps, [switch]$Dry) {
  $okAll = $true
  foreach ($s in @($steps)) {
    $a = $s.args.Clone(); if ($Dry -and $a.ContainsKey('maxCost')) { $a.maxCost = 1 }
    switch ($s.kind) {
      'road' { if (-not $Dry) { $a.start = Resolve $a.start; $a.end = Resolve $a.end }
        $b = RB batch_execute @{ steps = @(@{ command = 'build_road'; args = $a }) }; if (-not $b.result.id) { Write-Host "  SUBMIT FAILED $($s.label): $($b.error | ConvertTo-Json -Compress)"; $ok = $false } else { $r = (Wait-Batch $b.result.id).results[0]; $ok = Show-Result $s.label $r; if (-not $Dry) { $ok = $r.status -eq 'complete' } } }
      'network' { if (-not $Dry) { $a.start = Resolve $a.start; $a.end = Resolve $a.end }
        $b = RB batch_execute @{ steps = @(@{ command = 'build_network'; args = $a }) }; if (-not $b.result.id) { Write-Host "  SUBMIT FAILED $($s.label)"; $ok = $false } else { $r = (Wait-Batch $b.result.id).results[0]; $ok = Show-Result $s.label $r; if (-not $Dry) { $ok = $r.status -eq 'complete' } } }
      'upgrade' { if ($Dry) { Write-Host "  (dry) skipped, nothing built: upgrade_network has no preview ($($s.label))"; $ok = $true } else {
        $u = RB upgrade_network $a; $r = $u.result; if ($r.id -and $r.status -notin 'complete', 'failed') { $r = Wait-Op $r.id }
        if (-not $r.status) { Write-Host "  (no status) raw: $($u | ConvertTo-Json -Depth 4 -Compress)" }
        $ok = Show-Result $s.label $r; $ok = $r.status -eq 'complete' } }
      'demolish' { if ($Dry) { Write-Host "  (dry) would $($s.label)"; $ok = $true } else { $d = RB demolish $a; $r = $d.result; if ($r.id -and $r.status -notin 'complete', 'failed') { $r = Wait-Op $r.id }; $ok = $r.status -eq 'complete'; Write-Host ("  {0,-8} {1}" -f $(if ($ok) { 'DONE' } else { 'FAILED' }), $s.label) } }
    }
    if (-not $ok) { $okAll = $false; if (-not $Dry) { Write-Host '  STOPPED at the first failure'; break } }
  }
  Write-Host $(if ($okAll) { if ($Dry) { 'DRY RUN: all steps fit' } else { 'BUILD: all steps done' } } else { 'NOT all steps ok' })
  $okAll | Out-Null }

# ---- verification ----
# Dead ends (degree-1 nodes) in the area, and stacked nodes (same x,z within 1 m but different heights) = floating ends.
function Verify([double]$x, [double]$z, [double]$r = 300) {
  $es = Edges $x $z $r; $deg = @{}; $pos = @{}
  foreach ($e in $es) { foreach ($p in @(@("$($e.startNode.index)", $e.curve[0]), @("$($e.endNode.index)", $e.curve[3]))) { $deg[$p[0]]++; $pos[$p[0]] = $p[1] } }
  $dead = $deg.Keys | ? { $deg[$_] -eq 1 -and [math]::Pow($pos[$_].x - $x, 2) + [math]::Pow($pos[$_].z - $z, 2) -lt ($r - 30) * ($r - 30) }
  Write-Host "dead ends inside the area: $(@($dead).Count)"; $dead | % { Write-Host ("  node {0} at ({1},{2},y{3})" -f $_, [int]$pos[$_].x, [int]$pos[$_].z, [int]$pos[$_].y) }
  # pipe ends: a pipe node used by only one pipe and no road = possibly dangling (old road removed)
  $all = Edges $x $z $r -All; $pipes = $all | ? { $_.prefab -match 'Pipe' }; $roadNodes = @{}; $es | % { $roadNodes["$($_.startNode.index)"] = 1; $roadNodes["$($_.endNode.index)"] = 1 }
  $pdeg = @{}; $ppos = @{}; foreach ($p in $pipes) { foreach ($q in @(@("$($p.startNode.index)", $p.curve[0]), @("$($p.endNode.index)", $p.curve[3]))) { $pdeg[$q[0]]++; $ppos[$q[0]] = $q[1] } }
  $pend = $pdeg.Keys | ? { $pdeg[$_] -eq 1 -and -not $roadNodes[$_] -and [math]::Pow($ppos[$_].x - $x, 2) + [math]::Pow($ppos[$_].z - $z, 2) -lt ($r - 30) * ($r - 30) }
  Write-Host "pipe ends not on a road (check for dangling pipes / 'not connected' icons): $(@($pend).Count)"; $pend | Select -First 8 | % { Write-Host ("  pipe node {0} at ({1},{2})" -f $_, [int]$ppos[$_].x, [int]$ppos[$_].z) }
  $keys = @($pos.Keys); for ($i = 0; $i -lt $keys.Count; $i++) { for ($j = $i + 1; $j -lt $keys.Count; $j++) { $a = $pos[$keys[$i]]; $b = $pos[$keys[$j]]
      if ([math]::Abs($a.x - $b.x) -lt 1 -and [math]::Abs($a.z - $b.z) -lt 1 -and [math]::Abs($a.y - $b.y) -gt 2) { Write-Host ("  STACKED nodes {0} (y{1}) and {2} (y{3}) at ({4},{5}) - not connected" -f $keys[$i], [int]$a.y, $keys[$j], [int]$b.y, [int]$a.x, [int]$a.z) } } } }
# Shortest drivable distance between two node ids, using a fresh read of the area (all roads, one-ways respected).
function Route([long]$from, [long]$to, [double]$x, [double]$z, [double]$r = 1500) {
  $es = Edges $x $z $r; $adj = @{}
  foreach ($e in $es) { $a = "$($e.startNode.index)"; $b = "$($e.endNode.index)"; if (-not $adj[$a]) { $adj[$a] = @() }; $adj[$a] += , @($b, $e.length)
    if ($e.prefab -notmatch 'Oneway' -and $e.prefab -notmatch '^ra[0-9a-f]') { if (-not $adj[$b]) { $adj[$b] = @() }; $adj[$b] += , @($a, $e.length) } }
  $dist = @{ "$from" = 0.0 }; $done = @{}; $t = "$to"
  while ($true) { $best = $null; $bd = [double]::MaxValue; foreach ($k in @($dist.Keys)) { if (-not $done[$k] -and $dist[$k] -lt $bd) { $bd = $dist[$k]; $best = $k } }
    if (-not $best -or $best -eq $t) { break }; $done[$best] = 1; foreach ($n in $adj[$best]) { $nd = $bd + $n[1]; if (-not $dist.ContainsKey($n[0]) -or $nd -lt $dist[$n[0]]) { $dist[$n[0]] = $nd } } }
  if ($dist.ContainsKey($t)) { Write-Host ("route {0} -> {1}: {2:N0} m" -f $from, $to, $dist[$t]) } else { Write-Host "route $from -> ${to}: NO ROUTE" } }
function Water([double]$x, [double]$z, [double]$r = 300) {
  $bl = (RB get_buildings @{ x = $x; z = $z; radius = $r; limit = 400 }).result.buildings | ? { $_.waterConsumer }
  $bad = @($bl | ? { $_.waterConsumer.flags -notmatch 'WaterConnected' -or $_.waterConsumer.flags -notmatch 'SewageConnected' })
  Write-Host "water/sewage: $(@($bl).Count - $bad.Count) of $(@($bl).Count) buildings connected"; $bad | Select -First 5 | % { Write-Host "  missing: $($_.prefab) ($([int]$_.position.x),$([int]$_.position.z)) flags $($_.waterConsumer.flags)" } }
function Pipes-Near([double]$x, [double]$z, [double]$r = 40) { $p = (Edges $x $z $r -All) | ? { $_.prefab -match 'Pipe|Cable|voltage' }; Write-Host "utility lines within $r m: $(@($p).Count)"; $p | % { Write-Host "  $($_.index) $($_.prefab) ($([int]$_.curve[0].x),$([int]$_.curve[0].z))->($([int]$_.curve[3].x),$([int]$_.curve[3].z))" } }
function Refresh([double]$x, [double]$z, [double]$r = 300) { pwsh -NoProfile -File (Join-Path $Script:RoadData 'update-roads.ps1') -X $x -Z $z -Radius $r | % { Write-Host $_ } }
# Player rule (2026-11-07): road work happens with the game paused; everything else runs.
$Script:RunSpeedFile = Join-Path $env:CS2_BRIDGE_DIR 'run_speed.txt'
function Roadworks-Begin { Set-Content $Script:RunSpeedFile '0'; RB set_simulation_speed @{ speed = 0 } | Out-Null; Write-Host 'roadworks: game paused (auto-resume off)' }
function Roadworks-End([int]$speed = 2) { $s = $(if ($speed -eq 3) { 4 } else { $speed }); Set-Content $Script:RunSpeedFile "$s"; RB set_simulation_speed @{ speed = $s } | Out-Null; Write-Host "roadworks done: game speed $speed (auto-resume on)" }
Write-Host 'roadkit loaded: Look Stop-Game Go-Game Save Snap | Edges Edge NodeRef StartOf EndOf Pt OnT OnZ OnX | Road Pipe Upgrade Remove Run(-Dry) | Verify Route Water Pipes-Near Refresh'


