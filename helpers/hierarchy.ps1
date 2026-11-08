param([string]$Base, [string]$Patch, [string]$OutHtml, [string]$OutJson, [string[]]$RingIds = @())
$ring = @($RingIds)
$baseE = (Get-Content $Base -Raw | ConvertFrom-Json).result.edges
$patchE = (Get-Content $Patch -Raw | ConvertFrom-Json).result.edges
$pIds = @{}; $patchE | % { $pIds["$($_.index)"] = 1 }
$all = @($baseE | ? { -not $pIds["$($_.index)"] -and ("$($_.index)" -notin $ring) }) + @($patchE)

function Get-RoadClass($p) {
  if ($p -match 'Pipe|Line|Track') { return $null }
  if ($p -match 'Highway') { return 'Freeway' }
  if ($p -match 'Pedestrian|Alley') { return 'Local' }
  if ($p -match '^(Large Road|XL Road)|Medium Road Divided') { return 'Arterial' }
  if ($p -match '^Medium Road|Small Road Oneway - 3 lanes') { return 'Collector' }
  return 'Local'
}
$rank = @{ Freeway = 4; Arterial = 3; Collector = 2; Local = 1 }
$E = foreach ($x in $all) {
  $c = Get-RoadClass $x.prefab; if (-not $c) { continue }
  $d = ($x.trafficDistanceRaw | Measure -Sum).Sum
  [pscustomobject]@{ id = $x.index; prefab = $x.prefab; cls = $c; len = $x.length; flow = $d / [math]::Max($x.length, 1)
    a = "$($x.startNode.index)"; b = "$($x.endNode.index)"; pts = $x.curve }
}
# class medians (flow per metre)
$med = @{}; foreach ($g in ($E | Group-Object cls)) { $f = @($g.Group.flow | Sort-Object); $med[$g.Name] = $f[[int]($f.Count / 2)] }
# node incidence
$node = @{}; foreach ($x in $E) { foreach ($n in @($x.a, $x.b)) { if (-not $node[$n]) { $node[$n] = @() }; $node[$n] += $x } }
$issues = @()
foreach ($kv in $node.GetEnumerator()) {
  $cs = $kv.Value | % { $_.cls } | Sort-Object -Unique
  # A node where only 1-2 lane one-way ramps meet streets is a normal ramp terminal, not a problem.
  $mainline = $kv.Value | ? { $_.cls -eq 'Freeway' -and $_.prefab -notmatch 'Oneway - [12] lanes?$' }
  if ($mainline) {
    $low = $kv.Value | ? { $_.cls -in 'Local', 'Collector' }
    if ($low) {
      $x0 = $kv.Value[0]; $p = if ($x0.a -eq $kv.Key) { $x0.pts[0] } else { $x0.pts[3] }
      $worst = if ($low | ? { $_.cls -eq 'Local' }) { 'Local' } else { 'Collector' }
      $issues += [pscustomobject]@{ type = "Freeway meets $worst street"; sev = $(if ($worst -eq 'Local') { 3 } else { 2 }); x = [math]::Round($p.x); z = [math]::Round($p.z)
        detail = (($low | % { "$($_.prefab) ($([math]::Round($_.flow,1)))" }) -join ', ') }
    }
  }
}
foreach ($x in $E) {
  $lim = switch ($x.cls) { 'Local' { 2.3 } 'Collector' { 6.5 } 'Arterial' { 15 } default { $null } }
  if ($lim -and $x.flow -gt $lim -and $x.len -gt 30) {
    $m = $x.pts[1]
    $issues += [pscustomobject]@{ type = "$($x.cls) overloaded"; sev = $(if ($x.cls -eq 'Local') { 2 } elseif ($x.cls -eq 'Arterial') { 2 } else { 1 }); x = [math]::Round(($x.pts[0].x + $x.pts[3].x) / 2); z = [math]::Round(($x.pts[0].z + $x.pts[3].z) / 2)
      detail = "$($x.prefab) id $($x.id), $([math]::Round($x.len))m, load $([math]::Round($x.flow,1)) vs class limit $lim"; id = $x.id }
  }
}
# summary
$sum = $E | Group-Object cls | % { [pscustomobject]@{ cls = $_.Name; km = [math]::Round(($_.Group | Measure len -Sum).Sum / 1000, 1); medianLoad = [math]::Round($med[$_.Name], 1) } }
@{ summary = $sum; issues = ($issues | Sort-Object sev -Desc) } | ConvertTo-Json -Depth 4 | Out-File -Encoding utf8 $OutJson

# ---- SVG map ----
$xs = $E | % { $_.pts } | % { $_.x }; $zs = $E | % { $_.pts } | % { $_.z }
$minX = ($xs | Measure -Min).Minimum; $maxX = ($xs | Measure -Max).Maximum; $minZ = ($zs | Measure -Min).Minimum; $maxZ = ($zs | Measure -Max).Maximum
$W = 1000; $s = $W / ($maxX - $minX); $H = [math]::Ceiling(($maxZ - $minZ) * $s)
function X($v) { [math]::Round(($v - $minX) * $s, 1) }; function Z($v) { [math]::Round(($maxZ - $v) * $s, 1) }
$order = @{ Local = 0; Collector = 1; Arterial = 2; Freeway = 3 }
$over = @{}; $issues | ? { $_.id } | % { $over["$($_.id)"] = 1 }
$paths = foreach ($x in ($E | Sort-Object { $order[$_.cls] })) {
  $p = $x.pts; $d = "M$(X $p[0].x),$(Z $p[0].z)C$(X $p[1].x),$(Z $p[1].z) $(X $p[2].x),$(Z $p[2].z) $(X $p[3].x),$(Z $p[3].z)"
  $halo = if ($over["$($x.id)"]) { "<path d='$d' class='halo'/>" } else { '' }
  "$halo<path d='$d' class='r $($x.cls)'><title>$($x.prefab) | $($x.cls) | load $([math]::Round($x.flow,1)) | id $($x.id)</title></path>"
}
$dots = foreach ($i in ($issues | ? { $_.type -like 'Freeway*' })) { "<circle cx='$(X $i.x)' cy='$(Z $i.z)' r='$(if($i.sev -eq 3){6}else{4.5})' class='j s$($i.sev)'><title>$($i.type): $($i.detail) @ ($($i.x),$($i.z))</title></circle>" }
$mark = ''
$rows = ($issues | Sort-Object sev -Desc | Select -First 60 | % { "<tr><td>$($_.type)</td><td>($($_.x), $($_.z))</td><td>$($_.detail)</td></tr>" }) -join "`n"
$srows = ($sum | Sort-Object { - $rank[$_.cls] } | % { "<tr><td><span class='sw $($_.cls)'></span>$($_.cls)</td><td>$($_.km) km</td><td>$($_.medianLoad)</td></tr>" }) -join "`n"
$nFL = @($issues | ? { $_.type -eq 'Freeway meets Local street' }).Count; $nFC = @($issues | ? { $_.type -eq 'Freeway meets Collector street' }).Count
$nLO = @($issues | ? { $_.type -eq 'Local overloaded' }).Count; $nCO = @($issues | ? { $_.type -eq 'Collector overloaded' }).Count; $nAO = @($issues | ? { $_.type -eq 'Arterial overloaded' }).Count
@"
<!doctype html><html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'><title>Road Hierarchy Audit</title>
<style>
:root{--bg:#f7f6f2;--fg:#1d1d1b;--mut:#6b6a66;--card:#fff;--line:#e3e1db;--fw:#d0582b;--ar:#c9a227;--co:#3b82c4;--lo:#b9b6ad;--bad:#d62f6b;--warn:#8a4fd8}
@media (prefers-color-scheme:dark){:root:not([data-theme=light]){--bg:#171716;--fg:#ecebe6;--mut:#a3a19a;--card:#21211f;--line:#34332f;--lo:#5a5853}}
body{margin:0;background:var(--bg);color:var(--fg);font:14px/1.45 system-ui,sans-serif}
main{max-width:1100px;margin:0 auto;padding:20px 16px}
h1{font-size:22px;margin:0 0 4px}.sub{color:var(--mut);margin:0 0 16px}
.card{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:14px;margin-bottom:16px;overflow:auto}
.stats{display:flex;gap:12px;flex-wrap:wrap;margin-bottom:16px}.stat{flex:1 1 160px;background:var(--card);border:1px solid var(--line);border-radius:10px;padding:10px 12px}
.stat b{display:block;font-size:22px}.stat span{color:var(--mut);font-size:12px}
svg{width:100%;height:auto;display:block}
.r{fill:none;stroke-linecap:round}.Freeway{stroke:var(--fw);stroke-width:3.2}.Arterial{stroke:var(--ar);stroke-width:2.6}.Collector{stroke:var(--co);stroke-width:1.8}.Local{stroke:var(--lo);stroke-width:1}
.halo{fill:none;stroke:var(--bad);stroke-width:6;stroke-opacity:.35;stroke-linecap:round}
.j{stroke:var(--card);stroke-width:1.5}.s3{fill:var(--bad)}.s2{fill:var(--warn)}.new{fill:none;stroke:var(--fg);stroke-width:2;stroke-dasharray:3 3}
table{border-collapse:collapse;width:100%;font-size:13px}td,th{text-align:left;padding:5px 8px;border-bottom:1px solid var(--line);vertical-align:top}th{color:var(--mut);font-weight:600}
.sw{display:inline-block;width:18px;height:4px;border-radius:2px;margin-right:8px;vertical-align:middle}.sw.Freeway{background:var(--fw)}.sw.Arterial{background:var(--ar)}.sw.Collector{background:var(--co)}.sw.Local{background:var(--lo)}
.legend{display:flex;gap:16px;flex-wrap:wrap;color:var(--mut);font-size:12px;margin-top:8px}
</style></head><body><main>
<h1>City road hierarchy</h1><p class='sub'>Whole city. Hover a road for its type and load. Load = traffic per metre from the game's counters.</p>
<div class='stats'><div class='stat'><b>$nFL</b><span>freeway ↔ local street joins</span></div><div class='stat'><b>$nFC</b><span>freeway ↔ collector joins</span></div><div class='stat'><b>$nLO</b><span>local streets overloaded</span></div><div class='stat'><b>$nCO</b><span>collectors overloaded</span></div><div class='stat'><b>$nAO</b><span>arterials overloaded</span></div></div>
<div class='card'><svg viewBox='0 0 $W $H' role='img' aria-label='Road map coloured by hierarchy'>$($paths -join '')$($dots -join '')$mark</svg>
<div class='legend'><span><i class='sw Freeway'></i>Freeway</span><span><i class='sw Arterial'></i>Arterial (Large/XL/Medium Divided)</span><span><i class='sw Collector'></i>Collector (Medium)</span><span><i class='sw Local'></i>Local (Small/Alley)</span><span style='color:var(--bad)'>● freeway↔local</span><span style='color:var(--warn)'>● freeway↔collector</span><span style='color:var(--bad)'>▬ glow = overloaded for its class</span><span>◌ new crossroads</span></div></div>
<div class='card'><table><tr><th>Class</th><th>Length</th><th>Typical load</th></tr>$srows</table></div>
<div class='card'><table><tr><th>Issue</th><th>Location (x, z)</th><th>Detail</th></tr>$rows</table></div>
</main></body></html>
"@ | Out-File -Encoding utf8 $OutHtml
"done: $($E.Count) road edges, $($issues.Count) issues"







