# Rolling road map: re-reads only the area around (X,Z), patches the cached road data, and rebuilds the road
# hierarchy page. Use after any road build or demolish.
# Needs the game running with the bridge answering, and $env:CS2_BRIDGE_DIR set to the folder that holds bridge.ps1.
# Output (not committed): roads-cache\edges.json, roads-cache\road-hierarchy.html, roads-cache\issues.json
param([double]$X, [double]$Z, [double]$Radius = 600)
$ErrorActionPreference = 'Stop'
$dir = $PSScriptRoot
$bridge = $env:CS2_BRIDGE_DIR
if (-not $bridge -or -not (Test-Path (Join-Path $bridge 'bridge.ps1'))) { 'CS2_BRIDGE_DIR must point at the folder that contains bridge.ps1'; exit 1 }
$store = Join-Path $dir 'roads-cache'
New-Item -ItemType Directory -Force $store | Out-Null
$cache = Join-Path $store 'edges.json'
$html = Join-Path $store 'road-hierarchy.html'
$issuesJson = Join-Path $store 'issues.json'
$emptyPatch = Join-Path $store 'empty.json'
if (-not (Test-Path $emptyPatch)) { '{"result":{"edges":[]}}' | Set-Content -Encoding utf8 $emptyPatch }
Push-Location $bridge
$j = pwsh -NoProfile -File .\bridge.ps1 get_network_edges -ArgsJson (@{ x = $X; z = $Z; radius = $Radius; limit = 8192 } | ConvertTo-Json -Compress) | ConvertFrom-Json
Pop-Location
if (-not $j.ok) { "area read failed: $($j.error)"; exit 1 }
$fresh = @($j.result.edges)
$old = @()
if (Test-Path $cache) { $old = @((Get-Content $cache -Raw | ConvertFrom-Json).result.edges) }
function InArea($e) { foreach ($p in $e.curve) { if ([math]::Pow($p.x - $X, 2) + [math]::Pow($p.z - $Z, 2) -le $Radius * $Radius) { return $true } }; $false }
$freshIds = @{}; $fresh | ForEach-Object { $freshIds["$($_.index)"] = 1 }
$kept = @($old | Where-Object { -not $freshIds["$($_.index)"] -and -not (InArea $_) })
$removed = @($old | Where-Object { -not $freshIds["$($_.index)"] -and (InArea $_) }).Count
$oldIds = @{}; $old | ForEach-Object { $oldIds["$($_.index)"] = 1 }
$added = @($fresh | Where-Object { -not $oldIds["$($_.index)"] }).Count
$all = $kept + $fresh
@{ result = @{ edges = $all; updated = (Get-Date).ToString('s'); lastArea = @{ x = $X; z = $Z; radius = $Radius } } } | ConvertTo-Json -Depth 8 -Compress | Out-File -Encoding utf8 $cache
"cache: $($all.Count) edges (area read $($fresh.Count); new $added; removed $removed)"
pwsh -NoProfile -File (Join-Path $dir 'helpers\hierarchy.ps1') -Base $cache -Patch $emptyPatch -OutHtml $html -OutJson $issuesJson
"road hierarchy page refreshed: $html"
