# Scoped bridge dump: economy (per-service upkeep records, labelled), city totals, every bus line with stops,
# and waiting passengers per transit stop. Bridge reads only. Needs the game running with bridge controls on.
# Writes one JSON file to work\state.
$ErrorActionPreference = 'Continue'
$env:CS2_BRIDGE_DIR = if ($env:CS2_BRIDGE_DIR) { $env:CS2_BRIDGE_DIR } else { 'D:\CS2 MOD LITE\CitiesIIAgentBridge-0.5.0-community\CitiesIIAgentBridge-0.5.0-community' }
$kit = Split-Path $PSScriptRoot -Parent
. (Join-Path $kit 'work\scratch\2026-11-07\github-stage\cs2-bus-line-builder\roadkit.ps1') | Out-Null
$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')
$out = Join-Path $kit "work\state\bridge-dump-$stamp.json"
$state = (RB get_city_state @{}).result
$econ = $null; try { $econ = (RB get_service_economy @{}).result } catch { $econ = @{ error = "$($_.Exception.Message)" } }
$waitRes = $null; try { $waitRes = (RB get_stop_waiting @{}).result } catch { $waitRes = @{ error = "$($_.Exception.Message)" } }
$waitByIndex = @{}
foreach ($w in @($waitRes.entries)) { $waitByIndex["$($w.index)"] = $w }
$lines = @((RB get_transport_lines @{}).result.lines) | Where-Object { $_.transportType -eq 'Bus' }
$busLines = foreach ($l in $lines) {
  $stopRows = foreach ($wp in @($l.waypoints)) {
    $wt = $waitByIndex["$($wp.index)"]
    [ordered]@{ stop_index = $wp.stop.index; waypoint_index = $wp.index; waiting = if ($wt) { $wt.waiting } else { $null } }
  }
  [ordered]@{
    index = $l.index; number = $l.number; name = $l.name; complete = $l.complete
    stops = $l.stopCount; buses = $l.vehicleCount; passengers_aboard = $l.passengersAboard
    stop_waiting = @($stopRows)
    max_waiting_at_a_stop = (@($stopRows | ForEach-Object { $_.waiting } | Where-Object { $_ -ne $null }) | Measure-Object -Maximum).Maximum
  }
}
$dump = [ordered]@{
  captured_utc = (Get-Date).ToUniversalTime().ToString('o')
  city_session = $state.citySession
  simulation_frame = $state.simulationFrame
  speed = $state.selectedSpeed
  money = $state.money
  economy_services = $econ
  stop_waiting_summary = [ordered]@{ stops_reported = $waitRes.count; stops_with_waiting = @(@($waitRes.entries) | Where-Object { $_.waiting -gt 0 }).Count }
  bus_line_count = @($busLines).Count
  bus_lines = @($busLines)
  gaps = @('fee totals per service: the fee records are not labelled yet; cost totals are in economy_services.services')
}
$dump | ConvertTo-Json -Depth 8 | Set-Content $out
"bridge dump written: $out ($(@($busLines).Count) bus lines, $($waitRes.count) stops reported for waiting)"
