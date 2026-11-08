# Picks loop corners for a district from the bridge district atlas: for each outline vertex, the nearest unused
# road junction (3+ roads) inside the district's bounding box. Prints the corners in the order loop_gen.ps1 expects
# and the ready-to-run loop_gen command. Bridge reads only.
# Usage: pick_corners.ps1 -District "<district name>"
param([Parameter(Mandatory)][string]$District)
. (Join-Path $PSScriptRoot 'roadkit.ps1') | Out-Null
$d = @((RB get_district_atlas @{}).result.items | ? { $_.name -eq $District }) | Select-Object -First 1
if (-not $d -or $d.polygon.Count -lt 3) { Write-Host "district '$District' not found or has no outline"; exit 1 }
$poly = @($d.polygon)
$cx = ($poly | Measure-Object x -Average).Average; $cz = ($poly | Measure-Object z -Average).Average
$dists = @($poly | % { [math]::Sqrt([math]::Pow($_.x - $cx, 2) + [math]::Pow($_.z - $cz, 2)) }); $rad = ($dists | Measure-Object -Maximum).Maximum + 150
$es = @((RB get_network_edges @{ x = $cx; z = $cz; radius = $rad; limit = 6000 }).result.edges | ? { $_.prefab -notmatch 'Pipe|Cable|Line|voltage|Track|Subway|Pedestrian|Alley|Taxiway|Runway|Airplane|Marker|Path' })
$deg = @{}; $pos = @{}
foreach ($e in $es) { foreach ($q in @(@("$($e.startNode.index)", $e.curve[0]), @("$($e.endNode.index)", $e.curve[3]))) { $deg[$q[0]]++; $pos[$q[0]] = $q[1] } }
$minX = ($poly | Measure-Object x -Minimum).Minimum - 150; $maxX = ($poly | Measure-Object x -Maximum).Maximum + 150
$minZ = ($poly | Measure-Object z -Minimum).Minimum - 150; $maxZ = ($poly | Measure-Object z -Maximum).Maximum + 150
$junc = @($deg.Keys | ? { $deg[$_] -ge 3 -and $pos[$_].x -ge $minX -and $pos[$_].x -le $maxX -and $pos[$_].z -ge $minZ -and $pos[$_].z -le $maxZ } | % { [pscustomobject]@{ id = $_; x = [double]$pos[$_].x; z = [double]$pos[$_].z } })
$used = @{}; $picked = @()
foreach ($v in $poly) {
  $best = $junc | ? { -not $used[$_.id] } | Sort-Object { [math]::Pow($_.x - $v.x, 2) + [math]::Pow($_.z - $v.z, 2) } | Select-Object -First 1
  if ($best) { $used[$best.id] = 1; $picked += "{0},{1}" -f [math]::Round($best.x, 1), [math]::Round($best.z, 1) }
}
"district ${District}: outline $($poly.Count) vertices, junctions in box $($junc.Count), corners picked $($picked.Count)"
$corners = $picked -join ';'
"corners: $corners"
$tag = ($District -replace '[^A-Za-z]', '')
"loop_gen.ps1 -Name $tag -Cx $([math]::Round($cx)) -Cz $([math]::Round($cz)) -R $([math]::Round($rad)) -Corners `"$corners`""

