# Update check for cs2-bus-line-builder. Compares every file in this folder with the latest copy on GitHub.
# Reads only: it never downloads or changes local files. Uses the gh login if present, otherwise the public API.
# Usage: .\check-update.ps1                                  (branch main)
#        .\check-update.ps1 -Repo jgill03fd/cs2-bus-line-builder   (public edition)
param(
  [string]$Repo = 'jgill03fd/cs2-bus-line-builder',
  [string]$Branch = 'main'
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$treePath = "repos/$Repo/git/trees/${Branch}?recursive=1"

function Get-BlobSha([string]$path) {
  # Git's blob id: sha1 of "blob <size>\0" followed by the file bytes. GitHub reports the same id per file.
  $bytes = [IO.File]::ReadAllBytes($path)
  $header = [Text.Encoding]::ASCII.GetBytes("blob $($bytes.Length)`0")
  $all = New-Object byte[] ($header.Length + $bytes.Length)
  [Array]::Copy($header, 0, $all, 0, $header.Length)
  [Array]::Copy($bytes, 0, $all, $header.Length, $bytes.Length)
  $sha1 = [Security.Cryptography.SHA1]::Create()
  ([BitConverter]::ToString($sha1.ComputeHash($all))).Replace('-', '').ToLower()
}

function Get-RemoteTree {
  # Preferred: the gh login (private repos). Fallback: the public API (public repos only).
  $gh = @((Get-Command gh -ErrorAction SilentlyContinue).Source, 'C:\Program Files\GitHub CLI\gh.exe') | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
  if ($gh) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $raw = (& $gh api $treePath 2>$null | Out-String)
    $ErrorActionPreference = $prev
    $start = $raw.IndexOf('{')
    if ($start -ge 0) {
      $tree = $raw.Substring($start) | ConvertFrom-Json
      if ($tree.tree) { return $tree }
    }
  }
  Invoke-RestMethod -Uri ("https://api.github.com/" + $treePath) -Headers @{ 'User-Agent' = 'cs2-bus-line-builder-update-check' }
}

$tree = Get-RemoteTree
$remote = @{}
foreach ($t in $tree.tree) { if ($t.type -eq 'blob') { $remote[$t.path] = $t.sha } }

$changed = @(); $new = @(); $same = 0
foreach ($path in ($remote.Keys | Sort-Object)) {
  $local = Join-Path $root ($path.Replace('/', '\'))
  if (-not (Test-Path $local)) { $new += $path; continue }
  if ((Get-BlobSha $local) -eq $remote[$path]) { $same++ } else { $changed += $path }
}

if ($changed.Count -or $new.Count) {
  "UPDATE AVAILABLE: $($changed.Count) changed, $($new.Count) new file(s) in $Repo"
  foreach ($c in $changed) { "  changed: $c" }
  foreach ($n in $new) { "  new:     $n" }
  "Get the latest copy: https://github.com/$Repo (git pull, or download again). This check changed nothing on your machine."
} else {
  "up to date: $same file(s) match $Repo"
}

