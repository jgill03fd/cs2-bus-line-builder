param([ValidateSet('shot','click','key','drag','hover','rclick','scroll','restore','back')][string]$Action = 'shot', [int]$X = 0, [int]$Y = 0, [string]$Out = "$PSScriptRoot\game_shot.png", [double]$Scale = 0.5,
  [int]$X2 = 0, [int]$Y2 = 0, [string]$Keys = '', [switch]$Full, [switch]$Hold)
# Input/screenshots for the Cities: Skylines II window. Coordinates are GAME CLIENT pixels (1920x1080 = the game's own
# resolution) divided by -Scale; i.e. read them off a `shot -Scale s` image and pass the same -Scale.
# The game ignores posted (background) mouse messages, so real input is used, but kept short:
#  - the user's cursor position and active window are saved before the first input and restored after each
#    click/rclick/scroll/drag/key (unless -Hold). `hover` leaves the cursor in place (for tooltips); `restore` puts it back.
#  - `shot` never steals focus (it copies the game's client area from the screen).
# -Full: legacy 150%-scaling capture; not needed when the game is a plain 1920x1080 window.
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public static class W {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [StructLayout(LayoutKind.Sequential)] public struct PT { public int X, Y; }
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref PT p);
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out PT p);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, UIntPtr e);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern uint MapVirtualKey(uint c, uint t);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
}
"@
[W]::SetProcessDPIAware() | Out-Null
$p = Get-Process | ? { $_.ProcessName -match 'Cities2' -and $_.MainWindowHandle -ne 0 } | Select -First 1
if (-not $p) { "game window not found"; exit 1 }
$h = $p.MainWindowHandle
$cr = New-Object W+RECT; [W]::GetClientRect($h, [ref]$cr) | Out-Null
$o = New-Object W+PT; [W]::ClientToScreen($h, [ref]$o) | Out-Null
$w = $cr.R; $hgt = $cr.B
if ($Full) { $w = [int]($w * 1.5); $hgt = [int]($hgt * 1.5) }
$saveFile = "$PSScriptRoot\cursor_saved.txt"

function Save-User {   # remember the user's cursor + window once, before our first input
  if (Test-Path $saveFile) { return }
  $c = New-Object W+PT; [W]::GetCursorPos([ref]$c) | Out-Null; $fg = [W]::GetForegroundWindow()
  if ($fg -eq $h) { $fg = [IntPtr]::Zero }
  "$($c.X),$($c.Y),$($fg.ToInt64())" | Set-Content $saveFile
}
function Restore-User {
  if (-not (Test-Path $saveFile)) { return }
  $v = (Get-Content $saveFile) -split ','; Remove-Item $saveFile -ErrorAction SilentlyContinue
  [W]::SetCursorPos([int]$v[0], [int]$v[1]) | Out-Null
  $fg = [IntPtr][long]$v[2]
  if ($fg -ne [IntPtr]::Zero) { [W]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero); [W]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero); [W]::SetForegroundWindow($fg) | Out-Null }
}
function Focus-Game { if ([W]::IsIconic($h)) { [W]::ShowWindow($h, 9) | Out-Null }; if ([W]::GetForegroundWindow() -ne $h) { [W]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero); [W]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero); [W]::SetForegroundWindow($h) | Out-Null; Start-Sleep -Milliseconds 150 } }
function ToScreen([int]$x, [int]$y) { @(($o.X + [int]($x / $Scale)), ($o.Y + [int]($y / $Scale))) }
function MoveTo([int]$sx, [int]$sy) { [W]::SetCursorPos($sx - 3, $sy - 3) | Out-Null; Start-Sleep -Milliseconds 40; [W]::mouse_event(0x0001, 3, 3, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 120 }
function Done { if (-not $Hold) { Restore-User } }

switch ($Action) {
  'shot' {
    $bmp = New-Object System.Drawing.Bitmap $w, $hgt
    $g = [System.Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen($o.X, $o.Y, 0, 0, $bmp.Size); $g.Dispose()
    $sw = [int]($w * $Scale); $sh = [int]($hgt * $Scale)
    $small = New-Object System.Drawing.Bitmap $bmp, $sw, $sh; $small.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose(); $small.Dispose()
    "client ${w}x$hgt at ($($o.X),$($o.Y)); screenshot ${sw}x$sh saved to $Out (scale $Scale)"
  }
  'restore' { Restore-User; 'restored user cursor/window' }
  'key' {
    Save-User; Focus-Game
    $vk = @{ ctrl = 0x11; shift = 0x10; alt = 0x12; esc = 0x1B; enter = 0x0D; del = 0x2E; space = 0x20 }
    $parts = $Keys.ToLower().Split('+') | % { if ($vk.ContainsKey($_)) { [byte]$vk[$_] } else { [byte][char]$_.ToUpper() } }
    # the game ignores keys without hardware scan codes
    foreach ($k in $parts) { [W]::keybd_event($k, [byte][W]::MapVirtualKey($k, 0), 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 70 }
    [array]::Reverse($parts); foreach ($k in $parts) { [W]::keybd_event($k, [byte][W]::MapVirtualKey($k, 0), 2, [UIntPtr]::Zero); Start-Sleep -Milliseconds 50 }
    Done; "pressed $Keys"
  }
  'scroll' {
    Save-User; Focus-Game; $s = ToScreen $X $Y; MoveTo $s[0] $s[1]
    $n = [math]::Abs($X2); $d = $(if ($X2 -lt 0) { [uint32]4294967176 } else { [uint32]120 })
    for ($i = 0; $i -lt $n; $i++) { [W]::mouse_event(0x0800, 0, 0, $d, [UIntPtr]::Zero); Start-Sleep -Milliseconds 60 }
    Done; "scrolled $X2 at ($X,$Y)"
  }
  # mouse Back button (XButton1): clears one panel layer per press and drops the Bus Line Tool; -X2 = presses (default 1)
  'back' {
    Save-User; Focus-Game; $n = [math]::Max(1, $X2)
    for ($i = 0; $i -lt $n; $i++) { [W]::mouse_event(0x0080, 0, 0, 1, [UIntPtr]::Zero); Start-Sleep -Milliseconds 60; [W]::mouse_event(0x0100, 0, 0, 1, [UIntPtr]::Zero); Start-Sleep -Milliseconds 250 }
    Done; "back pressed $n time(s)"
  }
  'hover' { Save-User; Focus-Game; $s = ToScreen $X $Y; MoveTo $s[0] $s[1]; Start-Sleep -Milliseconds 200; "hover ($X,$Y)" }
  'rclick' {
    Save-User; Focus-Game; $s = ToScreen $X $Y; MoveTo $s[0] $s[1]
    [W]::mouse_event(0x0008, 0, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 80; [W]::mouse_event(0x0010, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 80; Done; "right-clicked ($X,$Y)"
  }
  'drag' {
    Save-User; Focus-Game; $s = ToScreen $X $Y; $e = ToScreen $X2 $Y2; MoveTo $s[0] $s[1]
    [W]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 200
    $steps = 20; $px = 0; $py = 0
    for ($i = 1; $i -le $steps; $i++) { $tx = [int](($e[0] - $s[0]) * $i / $steps); $ty = [int](($e[1] - $s[1]) * $i / $steps)
      $ux = [BitConverter]::ToUInt32([BitConverter]::GetBytes([int]($tx - $px)), 0); $uy = [BitConverter]::ToUInt32([BitConverter]::GetBytes([int]($ty - $py)), 0)
      [W]::mouse_event(0x0001, $ux, $uy, 0, [UIntPtr]::Zero); $px = $tx; $py = $ty; Start-Sleep -Milliseconds 25 }
    [W]::SetCursorPos($e[0], $e[1]) | Out-Null; Start-Sleep -Milliseconds 150; [W]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 80; Done; "dragged ($X,$Y) -> ($X2,$Y2)"
  }
  default {
    Save-User; Focus-Game; $s = ToScreen $X $Y; MoveTo $s[0] $s[1]
    [W]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 90; [W]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 80; Done; "clicked ($X,$Y) -> screen ($($s[0]),$($s[1]))"
  }
}
