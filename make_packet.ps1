# Builds the proposal packet (markdown) for a planned loop from its loop file and the shelter pre-check, so a person
# or an agent only adds the judgement (why, decision requested). Bridge reads only.
# Usage: make_packet.ps1 -LoopJson .\out\loop_Example.json -Title "Example district" -Out .\out\example_packet.md
#        [-Why "one line"] [-Depot "West Depot 2 (27 free)"] [-Radius 20]
param([Parameter(Mandatory)][string]$LoopJson, [Parameter(Mandatory)][string]$Title, [Parameter(Mandatory)][string]$Out,
      [string]$Why = '(add one line: why this loop)', [string]$Depot = '(name the depot and its free slots)', [double]$Radius = 20)
. (Join-Path $PSScriptRoot 'roadkit.ps1') | Out-Null
$loop = Get-Content $LoopJson -Raw | ConvertFrom-Json
$sets = @(); foreach ($s in 'cw', 'ccw') { if (@($loop.$s).Count) { $sets += $s } }
$all = @(); foreach ($s in $sets) { $all += @($loop.$s) }
$edges = @($all | % { $_.edge } | Select-Object -Unique).Count
$prefabs = ($all | Group-Object prefab | Sort-Object Count -Descending | % { "$($_.Name) ($($_.Count))" }) -join ', '
$oneway = @($all | ? { $_.prefab -match 'Oneway' }).Count
$clash = @(); $reuse = @()
foreach ($s in $sets) { foreach ($p in $loop.$s) {
  foreach ($st in @((RB get_transport_stops @{ x = [double]$p.shelter[0]; z = [double]$p.shelter[1]; radius = $Radius }).result.stops)) {
    $d = [math]::Round([math]::Sqrt([math]::Pow($st.position.x - $p.shelter[0], 2) + [math]::Pow($st.position.z - $p.shelter[1], 2)), 1)
    if (@($st.lines).Count) { $clash += "$s n$($p.n): stop $($st.index) at $d m ($(@($st.lines).Count) line(s))" } else { $reuse += "$s n$($p.n): unused stop $($st.index) at $d m (reusable)" } } } }
$n = $all.Count
$md = @"
# ${Title}: proposal for the Mayor ($((Get-Date).ToString('yyyy-MM-dd')))

Status: PROPOSED. Nothing placed.

## Why
$Why

## Loop
- File: $(Split-Path $LoopJson -Leaf)
- Length: CW $($loop.cwLength) m, CCW $($loop.ccwLength) m ($(@($loop.cw).Count) CW and $(@($loop.ccw).Count) CCW stops)
- Edges: $edges unique; prefabs: $prefabs
- One-way pieces: $oneway

## Shelter rule (stops of other lines within $Radius m)
- Clashes: $($clash.Count) of $n points
$(($clash | % { "  - $_" }) -join "`n")
- Reusable unused stops: $($reuse.Count)
$(($reuse | % { "  - $_" }) -join "`n")

## Build and cost
- Checkpoint, place shelters (about 400 each, $n points, about $($n * 400)), build the line(s), name, fleet at minimum.
- Buses from: $Depot
- No road change unless stated.

## Decision requested
APPROVE the build, or HOLD.
"@
Set-Content $Out $md
Write-Host "packet written: $Out (clashes $($clash.Count), reusable $($reuse.Count), one-way $oneway)"

