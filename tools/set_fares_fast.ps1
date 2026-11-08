# set_fares_fast.ps1 - sets the ticket price of many transit lines to "Free" through the Transportation Overview, in ONE process.
# Speed: the per-click helper approach (new pwsh per click/screenshot) took ~56 s per line; this takes ~8 s per line.
# Safety: the line panel layout changes between lines, so a fixed click spot can land on the "Assigned vehicles" slider and cut a
# fleet. This script finds the TICKET PRICE slider by its pixel pattern (grey track, a second slider 68-80 px below it), skips the
# line if it cannot confirm it, and checks that the knob is at the left end after the click.
# Coordinates: half-scale reference space (client x 0.5) for a 3840x2160 client at screen (0,0); every point is doubled for input
# (see profiles/3840x2160.json on the calibration branch). Other resolutions need their own values.
# Usage: set_fares_fast.ps1 -Jobs "notches,rowY;..." -TabY 631 -Out fares.png [-NoSet] [-KeepOpen]
#   rowY = list row of the line's magnifier icon (394,rowY); notches = wheel notches down from the top (0 for the first 6 rows).
#   Tabs (x=300): bus 631, train 679, tram 727, subway 775. Overview icon at (1640,1005). Overview close X (1655,510).
# Output: a montage of line name + ticket price per job, and a log of skipped or unverified lines.
param([string]$Jobs,[int]$TabY=631,[int]$PriceX=194,[int]$PriceY=314,[string]$Out,[switch]$NoSet,[switch]$KeepOpen)
# Fast, single-process fare setter. Coordinates are half-scale (x2 = physical px on the 3840x2160 client at 0,0).
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public static class F { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")] public static extern void mouse_event(uint f,uint dx,uint dy,uint d,UIntPtr e); [DllImport("user32.dll")] public static extern void keybd_event(byte v,byte s,uint f,UIntPtr e);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h); [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h,int c); [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h); }
"@
[F]::SetProcessDPIAware() | Out-Null
$p=Get-Process Cities2 | ? MainWindowHandle -ne 0 | select -First 1; $h=$p.MainWindowHandle
if([F]::IsIconic($h)){ [F]::ShowWindow($h,9) | Out-Null }
[F]::keybd_event(0x12,0,0,[UIntPtr]::Zero); [F]::keybd_event(0x12,0,2,[UIntPtr]::Zero); [F]::SetForegroundWindow($h) | Out-Null; Start-Sleep -Milliseconds 400
function MoveM($x,$y){ [F]::SetCursorPos($x*2-3,$y*2-3) | Out-Null; Start-Sleep -Milliseconds 30; [F]::mouse_event(1,3,3,0,[UIntPtr]::Zero); Start-Sleep -Milliseconds 70 }
function Ck($x,$y){ MoveM $x $y; [F]::mouse_event(2,0,0,0,[UIntPtr]::Zero); Start-Sleep -Milliseconds 70; [F]::mouse_event(4,0,0,0,[UIntPtr]::Zero); Start-Sleep -Milliseconds 60 }
function Wh($n){ $d=if($n -lt 0){[uint32]4294967176}else{[uint32]120}; for($i=0;$i -lt [math]::Abs($n);$i++){ [F]::mouse_event(0x800,0,0,$d,[UIntPtr]::Zero); Start-Sleep -Milliseconds 22 } }
function Shot(){ $b=New-Object Drawing.Bitmap 3840,2160; $g=[Drawing.Graphics]::FromImage($b); $g.CopyFromScreen(0,0,0,0,$b.Size); $g.Dispose(); $b }
function White($b,$x,$y){ $c=$b.GetPixel($x*2,$y*2); ($c.R -gt 200 -and $c.G -gt 200 -and $c.B -gt 200) }
function Gray($b,$x,$y){ $c=$b.GetPixel($x*2,$y*2); ($c.R -gt 130 -and [math]::Abs($c.R-$c.G) -lt 20 -and [math]::Abs($c.G-$c.B) -lt 20) }
function FindTicketY($b){ $runs=@(); $in=$false; for($y=240;$y -le 700;$y++){ $g=(Gray $b 500 $y) -and (Gray $b 450 $y); if($g -and -not $in){ $runs+=$y; $in=$true } elseif(-not $g){ $in=$false } }
  for($i=0;$i -lt $runs.Count-1;$i++){ $d=$runs[$i+1]-$runs[$i]; if($d -ge 68 -and $d -le 80){ return ($runs[$i]+2) } }; $null }
$log=@(); $crops=@(); $k=0
foreach($j in $Jobs -split ';'){
  $a=$j -split ','; $n=[int]$a[0]; $y=[int]$a[1]
  $b=Shot; $ov=White $b 1655 510; $lp=White $b 553 81; $b.Dispose()
  if(-not $ov){ if($lp){ Ck 553 81; Start-Sleep -Milliseconds 500 } else { Ck 1640 1005; Start-Sleep -Milliseconds 1500 } }
  Ck 300 $TabY; Start-Sleep -Milliseconds 400
  MoveM 1000 850; Wh 80; Start-Sleep -Milliseconds 250; if($n -ne 0){ Wh $n; Start-Sleep -Milliseconds 250 }
  Ck 394 $y; Start-Sleep -Milliseconds 1200
  $b=Shot; $open=White $b 553 81
  if(-not $open){ $log+="job $k : line panel did not open"; $b.Dispose(); $k++; continue }
  $ty=FindTicketY $b; $b.Dispose()
  if($null -eq $ty){ $log+="job $k : ticket slider not found, skipped"; if(-not $KeepOpen){ Ck 553 81; Start-Sleep -Milliseconds 400 }; $k++; continue }
  if(-not $NoSet){ Ck $PriceX $ty; Start-Sleep -Milliseconds 500; $v=Shot; $kn=$v.GetPixel(196*2,$ty*2); $v.Dispose(); if(-not ($kn.R -gt 200 -and $kn.G -gt 200 -and $kn.B -gt 200)){ $log+="job $k : knob not at left end (y=$ty)" } }
  $PriceY=$ty
  $b=Shot; $c=New-Object Drawing.Bitmap 400,70; $g=[Drawing.Graphics]::FromImage($c)
  $g.DrawImage($b,(New-Object Drawing.Rectangle 0,0,400,30),(New-Object Drawing.Rectangle 360,132,800,60),'Pixel'); $g.DrawImage($b,(New-Object Drawing.Rectangle 0,30,400,40),(New-Object Drawing.Rectangle 360,(($PriceY-39)*2),800,80),'Pixel'); $g.Dispose(); $b.Dispose(); $crops+=$c
  if(-not $KeepOpen){ Ck 553 81; Start-Sleep -Milliseconds 400 }
  $k++
}
$log
if($crops.Count){ $m=New-Object Drawing.Bitmap 400,(70*$crops.Count); $g=[Drawing.Graphics]::FromImage($m); for($i=0;$i -lt $crops.Count;$i++){ $g.DrawImage($crops[$i],0,70*$i) }; $m.Save($Out) }
"done $k jobs"



